# frozen_string_literal: true

namespace :fond do
  desc "Generate TypeScript types and hooks from Fond pages"
  task codegen: :environment do
    Rails.application.eager_load!
    dir = Rails.root.join(Fond.config.output_dir)
    changed = Fond::Codegen::Generator.new.write(dir.to_s)
    if changed.empty?
      puts "fond: output up to date"
    else
      changed.each { |f| puts "fond: wrote #{f}" }
    end
  end

  desc "Fail if generated output differs from committed files"
  task "codegen:check": :environment do
    Rails.application.eager_load!
    dir = Rails.root.join(Fond.config.output_dir)
    unless Fond::Codegen::Generator.new.check(dir.to_s)
      abort "fond: generated output is out of date. Run bin/rails fond:codegen and commit the result."
    end
    puts "fond: generated output is up to date"
  end
end
