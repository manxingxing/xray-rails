require "open3"

module Xray
  OPEN_PATH = '/_xray/open'
  UPDATE_CONFIG_PATH = '/_xray/config'

  # This middleware is responsible for injecting xray.js and the Xray bar into
  # the app's pages. It also listens for requests to open files with the user's
  # editor.
  class Middleware
    def initialize(app)
      @app = app
    end

    def call(env)
      # Request for opening a file path.
      if env['PATH_INFO'] == OPEN_PATH
        req, res = Rack::Request.new(env), Rack::Response.new
        out, _err, status = Xray.open_file(req.GET['path'])
        if status.success?
          res.status = 200
        else
          res.write out
          res.status = 500
        end
        res.finish
      elsif env['PATH_INFO'] == UPDATE_CONFIG_PATH
        req, res = Rack::Request.new(env), Rack::Response.new
        if req.post? && Xray.config.editor = req.POST['editor']
          res.status = 200
        else
          res.status = 400
        end
        res.finish

      # Inject xray.js and friends if this is a successful HTML response
      else
        status, headers, response = @app.call(env)

        if html_headers?(status, headers) && body = response_body(response)
          if Rails.application.config.assets.debug
            inject_xray_bar!(body)
            # don't inject js if there is already one
            unless body =~ script_matcher('xray')
              append_js!(body, 'xray', defer: true, 'data-turbolinks-eval' => false)
            end
          end

          content_length = body.bytesize.to_s

          # For rails v4.2.0+ compatibility
          if defined?(ActionDispatch::Response::RackBody) && ActionDispatch::Response::RackBody === response
            response = response.instance_variable_get(:@response)
          end

          # Modifying the original response obj maintains compatibility with other middlewares
          if ActionDispatch::Response === response
            response.body = [body]
            response.header['Content-Length'] = content_length unless committed?(response)
            response.to_a
          else
            headers['Content-Length'] = content_length
            [status, headers, [body]]
          end
        else
          [status, headers, response]
        end
      end
    end

    private

    def committed?(response)
      response.respond_to?(:committed?) && response.committed?
    end

    def render_xray_bar
      if ApplicationController.respond_to?(:render)
        # Rails 5
        ApplicationController.render(:partial => "/xray_bar").html_safe
      else
        # Rails <= 4.2
        ac = ActionController::Base.new
        ac.render_to_string(:partial => '/xray_bar').html_safe
      end
    end

    # Matches:
    #   <script src="/assets/jquery.js"></script>
    #   <script src="/assets/jquery-min.js"></script>
    #   <script src="/assets/jquery.min.1.9.1.js"></script>
    #   <script src="/assets/jquery.min.1.9.1-89255b9dbf3de2fbaa6754b3a00db431.js"></script>
    def script_matcher(script_name)
      /
        <script[^>]+
        \/#{script_name}
        (2|3)?                 # Optional jQuery version specification
        ([-.]{1}[\d\.]+)?      # Optional version identifier (e.g. -1.9.1)
        ([-.]{1}min)?          # Optional -min suffix
        (\.self)?              # Sprockets 3 appends .self to the filename
        (-\h{32,64})?          # Fingerprint varies based on Sprockets version
        \.js                   # Must have .js extension
        [^>]+><\/script>
      /x
    end

    def append_html(html, content = '')
      html.sub!(/<\/body>/) do
        content + "\n#{$~}".html_safe
      end
    end

    def inject_xray_bar!(html)
      append_html(html, render_xray_bar)
    end

    # Appends the given `script_name` after the `after_script_name`.
    def append_js!(html, script_name, *options)
      append_html(html, helper.javascript_include_tag(script_name, *options))
    end

    def helper
      ActionController::Base.helpers
    end

    def html_headers?(status, headers)
      status == 200 &&
      headers['Content-Type'] &&
      headers['Content-Type'].include?('text/html') &&
      headers["Content-Transfer-Encoding"] != "binary"
    end

    def response_body(response)
      body = ''
      response.each { |s| body << s.to_s }
      body
    end
  end
end
