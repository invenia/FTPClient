using Compat

module FTPClient
typealias RemoteRef Future

import Base: convert, show, open, mkdir, ascii, mv
import Base: readdir, cd, pwd, rm, close, download

type FTPClientError <: Exception
       msg::String
       lib_curl_error::Uint32
end

Base.showerror(io::IO, err::FTPClientError) = print(io, err.msg, " :: LibCURL error #", err.lib_curl_error)

export RequestOptions,
       Response,
       ConnContext,
       ftp_init,
       ftp_cleanup,
       ftp_connect,
       ftp_close_connection,
       ftp_get,
       ftp_put,
       ftp_command,
       FTP,
       upload,
       binary,
       rmdir,
       non_block_download,
       get_download_resp,
       non_block_upload,
       get_upload_resp,
       FTPClientError

include("FTPC.jl")
include("FTPObject.jl")

end
