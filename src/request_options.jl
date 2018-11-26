import Base: ==

struct RequestOptions
    uri::URI
    ssl::Bool
    verify_peer::Bool
    active_mode::Bool
end

"""
    RequestOptions(; kwargs...)

The options used to connect to an FTP server.

# Keywords
- `hostname::AbstractString="localhost"`: the hostname or address of the FTP server.
- `username::AbstractString=""`: the username used to access the FTP server.
- `password::AbstractString=""`: the password used to access the FTP server.
- `implicit::Bool=false`: use an implicit FTPS configuration.
- `ssl::Bool=false`: use a secure connection. Typically specified for explicit FTPS.
- `verify_peer::Bool=true`: verify authenticity of peer's certificate.
- `active_mode::Bool=false`: use active mode to establish data connection.
"""
function RequestOptions(;
    hostname::AbstractString="localhost",
    port::Integer=0,
    username::AbstractString="",
    password::AbstractString="",
    ssl::Bool=false,
    implicit::Bool=false,
    verify_peer::Bool=true,
    active_mode::Bool=false,
    url::AbstractString="",
)
    userinfo = if !isempty(password)
        username * ":" * password
    else
        username
    end

    uri = if isempty(url)
        scheme = ssl ? (implicit ? "ftps" : "ftpes") : "ftp"
        URI(scheme, hostname, port, "", "", "", userinfo)
    else
        Base.depwarn(string(
            "Using `RequestOptions` with the `url` keyword is deprecated; ",
            "use `RequestOptions(url, ...)` instead",
        ), :RequestOptions)
        URI(URI(url); userinfo=userinfo)
    end

    RequestOptions(uri, ssl, verify_peer, active_mode)
end

function RequestOptions(
    url::AbstractString;
    verify_peer::Bool=true,
    active_mode::Bool=false,
    ssl::Union{Nothing, Bool}=nothing,
)
    if ssl !== nothing
         Base.depwarn(
            "`RequestOptions` keyword `ssl` has been depprecated, change the URL " *
            "protocol to \"ftp://\", \"ftps://\", or \"ftpes://\" to respectively " *
            "indicate no security, implicit security, or explicit security.",
            :RequestOptions
        )
        url = ssl ? replace(url, "ftp://" => "ftpes://") : url
    end

    uri = URI(url)

    if !(uri.scheme in ("ftps", "ftp", "ftpes"))
        throw(ArgumentError("Unhandled FTP scheme: $(uri.scheme)"))
    end

    RequestOptions(
        uri,
        uri.scheme in ("ftps", "ftpes"),
        verify_peer,
        active_mode,
    )
end

function security(opts::RequestOptions)
    opts.ssl ? (opts.uri.scheme == "ftps" ? :implicit : :explicit) : :none
end

ispassive(opts::RequestOptions) = !opts.active_mode

function ==(this::RequestOptions, other::RequestOptions)
    return (
        this.uri == other.uri &&
        this.ssl == other.ssl &&
        this.verify_peer == other.verify_peer &&
        this.active_mode == other.active_mode
    )
end

setup_easy_handle(options::RequestOptions) = setup_easy_handle(ConnContext(options))

"""
    ftp_get(
        options::RequestOptions,
        file_name::AbstractString,
        save_path::AbstractString="";
        mode::FTP_MODE=binary_mode,
        verbose::Union{Bool,IOStream}=false,
    )

Download a file with a non-persistent connection. Returns a `Response`.

# Arguments
* `options::RequestOptions`: the connection options. See `RequestOptions` for details.
* `file_name::AbstractString`: the path to the file on the server.
* `save_path::AbstractString=""`: if not specified the file is written to the `Response`
    body.
* `mode::FTP_MODE=binary_mode`: defines whether the file is transferred in binary or ASCII
    format.
* `verbose::Union{Bool,IOStream}=false`: an `IOStream` to capture LibCurl's output or a
    `Bool`, if true output is written to STDERR.
"""
function ftp_get(
    options::RequestOptions,
    file_name::AbstractString,
    save_path::AbstractString="";
    mode::FTP_MODE=binary_mode,
    verbose::Union{Bool,IOStream}=false,
)
    ctxt = setup_easy_handle(options)
    try
        return ftp_get(ctxt, file_name, save_path; mode=mode, verbose=verbose)
    finally
        cleanup_easy_context(ctxt)
    end
end

"""
    ftp_put(
        options::RequestOptions,
        file_name::AbstractString,
        file::IO;
        mode::FTP_MODE=binary_mode,
        verbose::Union{Bool,IOStream}=false,
    )

Upload file with non-persistent connection. Returns a Response.

# Arguments
* `options::RequestOptions`: the connection options. See `RequestOptions` for details.
* `file_name::AbstractString`: the path to the file on the server.
* `file::IO`: what is being written to the server.
* `mode::FTP_MODE=binary_mode`: defines whether the file is transferred in binary or
    ASCII format.
* `verbose::Union{Bool,IOStream}=false`: an `IOStream` to capture LibCurl's output or a
    `Bool`, if true output is written to STDERR.
"""
function ftp_put(
    options::RequestOptions,
    file_name::AbstractString,
    file::IO;
    mode::FTP_MODE=binary_mode,
    verbose::Union{Bool,IOStream}=false,
)
    ctxt = setup_easy_handle(options)
    try
        return ftp_put(ctxt, file_name, file; mode=mode, verbose=verbose)
    finally
        cleanup_easy_context(ctxt)
    end
end

"""
    ftp_command(
        options::RequestOptions,
        cmd::AbstractString;
        verbose::Union{Bool,IOStream}=false,
    )

Pass FTP command with non-persistent connection. Returns a `Response`.
"""
function ftp_command(
    options::RequestOptions,
    cmd::AbstractString;
    verbose::Union{Bool,IOStream}=false,
)
    ctxt = setup_easy_handle(options)
    try
        return ftp_command(ctxt, cmd; verbose=verbose)
    finally
        cleanup_easy_context(ctxt)
    end
end

"""
    ftp_connect(options::RequestOptions; verbose::Union{Bool,IOStream}=false)

Establish connection to FTP server. Returns a `ConnContext` and a `Response`.
"""
function ftp_connect(options::RequestOptions; verbose::Union{Bool,IOStream}=false)
    ctxt = setup_easy_handle(options)
    try
        # ping the server
        resp = ftp_command(ctxt, "LIST"; verbose=verbose)

        return ctxt, resp
    catch
        cleanup_easy_context(ctxt)
        rethrow()
    end
end
