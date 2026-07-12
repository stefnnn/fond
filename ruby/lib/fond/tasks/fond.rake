# frozen_string_literal: true

namespace :fond do
  desc "Generate TypeScript types and hooks from Fond pages"
  task codegen: :environment do
    puts "fond: codegen not implemented yet"
  end

  desc "Fail if generated output differs from committed files"
  task "codegen:check": :environment do
    puts "fond: codegen:check not implemented yet"
  end
end
