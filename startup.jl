using GenieFramework
# https://learn.genieframework.com/docs/reference/workflow/nginx-reverse-proxy
# ENV["BASEPATH"] = "/water"

# julia --project=. --startup-file=no -t4 startup.jl

Genie.config.websockets_server = true
HACK_PROD=true
if HACK_PROD 
    Genie.Configuration.config!(
    server_port                     = 8081,
    server_host                     = "0.0.0.0",
    # log_level                       = Logging.Error,
    # log_to_file                     = false,
    server_handle_static_files      = true, # for best performance set up Nginx or Apache web proxies and set this to false
    path_build                      = "build",
    format_julia_builds             = false,
    format_html_output              = false
    )

    ENV["JULIA_REVISE"] = "off"
end

Genie.loadapp() # ".",autostart=false )
println( "app loaded, trying up")

up()