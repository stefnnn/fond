# frozen_string_literal: true

require_relative "test_helper"
require "fond/routes"
require "tmpdir"

class SharedPropsCodegenTest < Minitest::Test
  def setup
    Fond::Registry.reset!
  end

  def test_types_and_hooks_with_shared_props_class
    dto = Class.new(T::Struct) { const :label, String }
    Object.const_set(:SpCoOnlySharedDTO, dto)
    shared = Class.new(T::Struct) do
      const :current_user_id, Integer
      const :flag, dto
    end
    Object.const_set(:SpCoSharedProps, shared)

    page = build_page("SpCoIndexPage", props: build_props(:total, Integer))
    mutation = build_mutation("SpCoCreateMutation", params: build_params(:name, String))

    generator = Fond::Codegen::Generator.new(
      pages: [page],
      bindings: [binding_for(page, "/sp", [])],
      mutations: [mutation],
      mutation_bindings: [mutation_binding_for(mutation, "/sp", "POST", [])],
      shared_props_class: shared
    )

    types = generator.types_ts
    assert_includes types, "export interface SpCoSharedProps {"
    assert_includes types, "currentUserId: number;"
    assert_includes types, "flag: SpCoOnlySharedDTO;"
    assert_includes types, "export interface SpCoOnlySharedDTO {\n  label: string;\n}"

    hooks = generator.hooks_ts
    assert_includes hooks, "import { useMutation, usePageProps, useSharedProps, type Mutation } from \"fond\";"
    assert_includes hooks, "import type { SpCoCreateParams, SpCoIndexProps, SpCoSharedProps } from \"./types\";"
    assert_includes hooks, "export function useShared(): SpCoSharedProps {\n  return useSharedProps<SpCoSharedProps>();\n}"

    page_idx = hooks.index("export function useSpCoIndex")
    shared_idx = hooks.index("export function useShared")
    mutation_idx = hooks.index("export function useSpCoCreate")
    assert_operator page_idx, :<, shared_idx
    assert_operator shared_idx, :<, mutation_idx
  ensure
    remove_pages(:SpCoIndexPage, :SpCoCreateMutation, :SpCoSharedProps, :SpCoOnlySharedDTO)
  end

  def test_no_trace_without_shared_props_class
    page = build_page("SpCoPlainIndexPage", props: build_props(:total, Integer))

    generator = Fond::Codegen::Generator.new(
      pages: [page],
      bindings: [binding_for(page, "/sp-plain", [])]
    )

    refute_includes generator.hooks_ts, "useSharedProps"
    refute_includes generator.hooks_ts, "useShared"
    refute_includes generator.types_ts, "SharedProps"
  ensure
    remove_pages(:SpCoPlainIndexPage)
  end

  def test_default_shared_props_class_from_config
    shared = Class.new(T::Struct) { const :ok, T::Boolean }
    Object.const_set(:SpCoConfigSharedProps, shared)
    original = Fond.config.shared_props_class_name
    Fond.config.shared_props_class_name = "SpCoConfigSharedProps"

    page = build_page("SpCoConfigIndexPage", props: build_props(:total, Integer))
    generator = Fond::Codegen::Generator.new(
      pages: [page],
      bindings: [binding_for(page, "/sp-config", [])]
    )

    assert_includes generator.hooks_ts, "export function useShared(): SpCoConfigSharedProps {"
  ensure
    Fond.config.shared_props_class_name = original
    remove_pages(:SpCoConfigIndexPage, :SpCoConfigSharedProps)
  end

  def test_determinism_with_shared_props_class
    shared = Class.new(T::Struct) { const :a, Integer }
    Object.const_set(:SpCoDetSharedProps, shared)
    page = build_page("SpCoDetIndexPage", props: build_props(:total, Integer))
    bindings = [binding_for(page, "/sp-det", [])]

    first = Fond::Codegen::Generator.new(pages: [page], bindings: bindings, shared_props_class: shared)
    second = Fond::Codegen::Generator.new(pages: [page], bindings: bindings, shared_props_class: shared)

    assert_equal first.hooks_ts, second.hooks_ts
    assert_equal first.types_ts, second.types_ts
  ensure
    remove_pages(:SpCoDetIndexPage, :SpCoDetSharedProps)
  end

  def test_write_and_check_roundtrip_with_shared_props_class
    shared = Class.new(T::Struct) { const :a, Integer }
    Object.const_set(:SpCoWriteSharedProps, shared)
    page = build_page("SpCoWriteIndexPage", props: build_props(:total, Integer))

    generator = Fond::Codegen::Generator.new(
      pages: [page],
      bindings: [binding_for(page, "/sp-write", [])],
      shared_props_class: shared
    )

    Dir.mktmpdir do |dir|
      changed = generator.write(dir)
      names = %w[types.ts pages.ts hooks.ts paths.ts]
      expected_paths = names.map { |n| File.join(dir, n) }
      assert_equal expected_paths.sort, changed.sort
      assert generator.check(dir)
      assert_equal [], generator.write(dir)
    end
  ensure
    remove_pages(:SpCoWriteIndexPage, :SpCoWriteSharedProps)
  end

  private

  def binding_for(page, path, required_params)
    Fond::Routes::Binding.new(page: page, path: path, verb: "GET", required_params: required_params)
  end

  def mutation_binding_for(mutation, path, verb, required_params)
    Fond::Routes::Binding.new(page: mutation, path: path, verb: verb, required_params: required_params)
  end

  def build_props(name, type)
    Class.new(T::Struct) { const name, type }
  end

  def build_params(name, type)
    Class.new(T::Struct) { const name, type }
  end

  def build_page(name, props:, params: nil)
    page = Class.new(Fond::Page)
    Object.const_set(name, page)
    page.const_set(:Params, params) if params
    page.const_set(:Props, props)
    page
  end

  def build_mutation(name, params:, props: nil)
    mutation = Class.new(Fond::Mutation)
    Object.const_set(name, mutation)
    mutation.const_set(:Params, params)
    mutation.const_set(:Props, props) if props
    mutation
  end

  def remove_pages(*names)
    names.each { |n| Object.send(:remove_const, n) if Object.const_defined?(n) }
  end
end
