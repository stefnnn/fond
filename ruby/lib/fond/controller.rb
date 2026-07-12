# typed: false
# frozen_string_literal: true

module Fond
  # Controller integration. Include in ApplicationController, then:
  #
  #   class OrdersController < ApplicationController
  #     page Orders::IndexPage
  #     def index(params)          # typed Params instance
  #       Props.new(...)           # rendered automatically
  #     end
  #   end
  #
  # The action name is inferred from the page class (Orders::IndexPage →
  # :index); pass `action:` to override. Returning anything other than the
  # page's Props (or having already rendered) opts out — `render_page` is
  # the explicit escape hatch.
  module Controller
    def self.included(base)
      base.extend(ClassMethods)
    end

    module ClassMethods
      def page(page_class, action: nil)
        action ||= page_class.component_name.split("/").last
        fond_pages[action.to_sym] = page_class
      end

      def fond_pages
        @fond_pages ||= superclass.respond_to?(:fond_pages) ? superclass.fond_pages.dup : {}
      end

      def fond_page_for(action)
        fond_pages[action.to_sym]
      end
    end

    def render_page(props, page: nil)
      page ||= self.class.fond_page_for(action_name)
      raise Fond::Error, "no page declared for #{self.class}##{action_name}" unless page

      payload = {
        component: page.component_name,
        props: Fond::Serialize.to_wire(props),
        url: request.fullpath,
        version: Fond.config.version.call
      }

      if fond_request?
        response.set_header("Vary", "X-Fond")
        render json: payload
      else
        render_fond_html(payload)
      end
    end

    private

    # BasicImplicitRender#send_action calls default_render inside super —
    # before we could see the return value — so fond actions dispatch via
    # plain send and replicate the implicit-render fallback afterwards.
    def send_action(method_name, *args)
      page_class = self.class.fond_page_for(method_name)
      return super unless page_class

      response.set_header("Vary", "X-Fond")
      return if fond_version_mismatch?

      typed_params = build_fond_params(page_class)
      return if performed?

      result =
        if method(method_name).arity.zero?
          send(method_name)
        else
          send(method_name, typed_params)
        end

      render_page(result, page: page_class) if !performed? && result.is_a?(T::Struct)
      default_render unless performed?
      result
    end

    def fond_request?
      request.headers["X-Fond"] == "true"
    end

    def fond_version_mismatch?
      return false unless fond_request?

      client_version = request.headers["X-Fond-Version"]
      return false if client_version.nil? || client_version == Fond.config.version.call

      response.set_header("X-Fond-Location", request.fullpath)
      head :conflict
      true
    end

    def build_fond_params(page_class)
      params_class = page_class.params_class
      return nil unless params_class

      raw = request.path_parameters.except(:controller, :action, :format)
                   .stringify_keys
                   .merge(request.query_parameters)
                   .merge(fond_body_parameters)
      Fond::Coerce.struct(params_class, raw)
    rescue Fond::Coerce::Error => e
      render json: { error: "invalid_params", errors: e.errors }, status: :bad_request
      nil
    end

    def fond_body_parameters
      return {} unless request.post? || request.put? || request.patch? || request.delete?

      request.request_parameters.except("controller", "action", "format")
    end

    def render_fond_html(payload)
      json = payload.to_json.gsub('<', '\u003c')
      html = <<~HTML.html_safe
        <div id="fond-root"></div>
        <script type="application/json" id="fond-page-data">#{json}</script>
      HTML
      render html: html, layout: true
    end
  end
end
