# frozen_string_literal: true

require "active_support/descendants_tracker"

module ViewComponent # :nodoc:
  class Preview
    include ActionView::Helpers::TagHelper
    include ActionView::Helpers::AssetTagHelper
    extend ActiveSupport::DescendantsTracker

    def render(component, **args, &block)
      {
        args: args,
        block: block,
        component: component,
        locals: {},
        template: "view_components/preview",
      }
    end

    def render_with_template(template: nil, locals: {})
      {
        template: template,
        locals: locals
      }
    end

    alias_method :render_component, :render

    class << self
      # Returns all component preview classes.
      def all
        load_previews if descendants.empty?
        descendants
      end

      # Returns the arguments for rendering of the component in its layout
      def render_args(example, params: {})
        example_params_names = instance_method(example).parameters.map(&:last)
        provided_params = params.slice(*example_params_names).to_h.symbolize_keys
        result = provided_params.empty? ? new.public_send(example) : new.public_send(example, **provided_params)
        result ||= {}
        result[:template] = preview_example_template_path(example) if result[:template].nil?
        @layout = nil unless defined?(@layout)
        result.merge(layout: @layout)
      end

      # Returns all of the available examples for the component preview.
      def examples
        public_instance_methods(false).map(&:to_s).sort
      end

      # Returns +true+ if the preview exists.
      def exists?(preview)
        all.any? { |p| p.preview_name == preview }
      end

      # Find a component preview by its underscored class name.
      def find(preview)
        all.find { |p| p.preview_name == preview }
      end

      # Returns the underscored name of the component preview without the suffix.
      def preview_name
        name.chomp("Preview").underscore
      end

      # Setter for layout name.
      def layout(layout_name)
        @layout = layout_name
      end

      # Returns the relative path (from preview_path) to the preview example template if the template exists
      def preview_example_template_path(example)
        preview_path =
          Array(preview_paths).detect do |path|
            Dir["#{path}/#{preview_name}_preview/#{example}.html.*"].first
          end

        if preview_path.nil?
          raise(
            PreviewTemplateError,
            "A preview template for example #{example} doesn't exist.\n\n" \
            "To fix this issue, create a template for the example."
          )
        end

        path = Dir["#{preview_path}/#{preview_name}_preview/#{example}.html.*"].first
        Pathname.new(path).
          relative_path_from(Pathname.new(preview_path)).
          to_s.
          sub(/\..*$/, "")
      end

      # Returns the method body for the example from the preview file.
      def preview_source(example)
        source = self.instance_method(example.to_sym).source.split("\n")
        source[1...(source.size - 1)].join("\n")
      end

      private

      def load_previews
        Array(preview_paths).each do |preview_path|
          Dir["#{preview_path}/**/*_preview.rb"].sort.each { |file| require_dependency file }
        end
      end

      def preview_paths
        Base.preview_paths
      end
    end
  end
end
