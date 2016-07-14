# FTPClient
FTP client based on [LibCURL.jl](https://github.com/JuliaWeb/LibCURL.jl).

[![Build Status](https://travis-ci.org/invenia/FTPClient.jl.svg?branch=master)](https://travis-ci.org/invenia/FTPClient.jl)
[![Build status](https://ci.appveyor.com/api/projects/status/sqsge28jvto74nhs/branch/master?svg=true)](https://ci.appveyor.com/project/adrienne-pind-invenia/ftpclient-jl/branch/master)
[![codecov.io](http://codecov.io/github/invenia/FTPClient.jl/coverage.svg)](http://codecov.io/github/invenia/FTPClient.jl)
[![Dependency Status](https://dependencyci.com/github/invenia/FTPClient.jl/badge)](https://dependencyci.com/github/invenia/FTPClient.jl)

### Requirement

Tested with julia `Version 0.4.0-dev+6673`

### Usage

#### FTPC functions
`ftp_init()` and  `ftp_cleanup()` need to be used once per session.

Functions for non-persistent connection:
```julia
ftp_get(file_name::AbstractString, options::RequestOptions, save_path::AbstractString)
ftp_put(file_name::AbstractString, file::IO, options::RequestOptions)
ftp_command(cmd::AbstractString, options::RequestOptions)
```
- These functions all establish a connection, perform the desired operation then close the connection and return a `Response` object. Any data retrieved from server is in `Response.body`.

    ```julia
    type Response
        body::IO
        headers::Vector{AbstractString}
        code::Int
        total_time::FloatingPoint
        bytes_recd::Int
    end
    ```

Functions for persistent connection:
```julia
ftp_connect(options::RequestOptions)
ftp_get(ctxt::ConnContext, file_name::AbstractString, save_path::AbstractString)
ftp_put(ctxt::ConnContext, file_name::AbstractString, file::IO)
ftp_command(ctxt::ConnContext, cmd::AbstractString)
ftp_close_connection(ctxt::ConnContext)
```
- These functions all return a `Response` object, except `ftp_close_connection`, which does not return anything. Any data retrieved from server is in `Response.body`.

    ```julia
    type ConnContext
        curl::Ptr{CURL}
        url::AbstractString
        options::RequestOptions
    end
    ```

- `url` is of the form "localhost" or "127.0.0.1"
- `cmd` is of the form "PWD" or "CWD Documents/", and must be a valid FTP command
- `file_name` is both the name of the file that will be retrieved/uploaded and the name it will be saved as
- `options` is a `RequestOptions` object

    ```julia
    type RequestOptions
        blocking::Bool
        implicit::Bool
        ssl::Bool
        verify_peer::Bool
        active_mode::Bool
        headers::Vector{Tuple}
        username::AbstractString
        passwd::AbstractString
        url::AbstractString
        binary_mode::Bool
    end
    ```
    - `blocking`: default is true
    - `implicit`: use implicit security, default is false
    - `ssl`: use FTPS, default is false
    - `verify_peer`: verify authenticity of peer's certificate, default is true
    - `active_mode`: use active mode to establish data connection, default is false
    - `binary_mode`: used to tell the client to download files in binary mode, default is true


#### FTPObject functions
```julia
FTP(;host="", block=true, implt=false, ssl=false, ver_peer=true, act_mode=false, user="", pswd="", binary_mode=true)
close(ftp::FTP)
download(ftp::FTP, file_name::AbstractString, save_path::AbstractString="")
upload(ftp::FTP, local_name::AbstractString)
upload(ftp::FTP, local_name::AbstractString, remote_name::AbstractString)
upload(ftp::FTP, local_file::IO, remote_name::AbstractString)
readdir(ftp::FTP)
cd(ftp::FTP, dir::AbstractString)
pwd(ftp::FTP)
rm(ftp::FTP, file_name::AbstractString)
rmdir(ftp::FTP, dir_name::AbstractString)
mkdir(ftp::FTP, dir::AbstractString)
mv(ftp::FTP, file_name::AbstractString, new_name::AbstractString)
binary(ftp::FTP)
ascii(ftp::FTP)
```
### Examples

Using non-peristent connection and FTPS with implicit security:
```julia
using FTPClient

ftp_init()
options = RequestOptions(ssl=true, implicit=true, username="user1", passwd="1234", url="localhost")

resp = ftp_get("download_file.txt", options)
io_buffer = resp.body

resp = ftp_get("download_file.txt", options, "Documents/downloaded_file.txt")
io_stream = resp.body

file = open("upload_file.txt")
resp = ftp_put("upload_file.txt", file, options)
close(file)

resp = ftp_command("LIST", options)
dir = resp.body

ftp_cleanup()
```

Using persistent connection and FTPS with explicit security:
```julia
using FTPClient

ftp_init()
options = RequestOptions(ssl=true, username="user2", passwd="5678", url="localhost")

ctxt = ftp_connect(options)

resp = ftp_get(ctxt, "download_file.txt")
io_buffer = resp.body

resp = ftp_get(ctxt, "download_file.txt", "Documents/downloaded_file.txt")
io_stream = resp.body

resp = ftp_command(ctxt, "CWD Documents/")

file = open("upload_file.txt")
resp = ftp_put(ctxt, "upload_file.txt", file)
close(file)

ftp_close_connection(ctxt)

ftp_cleanup()
```

Using the FTP object with a persistent connection and FTPS with implicit security:
```julia
ftp_init()
ftp = FTP(host="localhost", implt=true, ssl=true, user="user3", pswd="2468" )

dir_list = readdir(ftp)
cd(ftp, "Documents/School")
pwd(ftp)

# download file contents to buffer
buff = download(ftp, "Assignment1.txt")

# download and save file to specified path
file = download(ftp, "Assignment2.txt", "./A2/Assignment2.txt")

# upload file upload_file_name
upload(ftp, upload_file_name)

# upload file upload_file_name and change name to "new_name"
upload(ftp, upload_file_name, "new_name")

# upload contents of buffer and save to file
buff = IOBuffer("Buffer to upload.")
upload(ftp, buff, "upload_buffer.txt")

# upload local file to server
upload(ftp, file, "upload_file.txt")

mv(ftp, "upload_file.txt", "Assignment3.txt")

rm(ftp, "upload_buffer.txt")

mkdir(ftp, "TEMP_DIR")
rmdir(ftp, "TEMP_DIR")

# set transfer mode to binary or ascii
binary(ftp)
ascii(ftp)

close(ftp)
ftp_cleanup()
```

### Running Tests

Getting the tests to work involves setting up a mock server. Most of our tests use this [mock FTP server](http://mockftpserver.sourceforge.net/). Since the mock FTP sever, does not support ssl, there are manual tests for ssl connections.

#### Typical Non-SSL Tests

You need to set up the mock FTP server. To set it up:
- Add the [JavaCall.jl](https://github.com/aviks/JavaCall.jl) package with `Pkg.add("JavaCall”)` (If you are using 0.5, see 0.5 Issues below)
- Build dependencies via `Pkg.build("FTPClient")`

You do not need to rebuild the mock FTP server for every test. To run the tests
```julia
Pkg.test("FTPClient")
```

#### Manual Tests

This is only needed when testing ssl connection. You will need to set up your own FTP server and configure it for ssl connections. I used vsftpd on my Mac and a Debian VM.

The tests follow this patter
```
`julia --color=yes test/runtests.jl <test_ssl> <test_implicit> <username> <password> <hostname>
```

The ssl tests can be run if you have a FTP server set up.
- To run the tests using implicit security: `julia --color=yes test/runtests.jl true true <username> <password> <hostname>`
- To run the tests using explicit security: `julia --color=yes test/runtests.jl true false <username> <password> <hostname>`

Here is what I would run when testing with my FTP server. `julia --color=yes test/runtests.jl true true test password 172.16.105.129`

The tests assume that your FTP server contains `test_download.txt` file.
When you run your tests, your sever will receive a `test_update.txt` file.

#### 0.5 Issues

[JavaCall.jl is not working in 0.5](https://github.com/aviks/JavaCall.jl/pull/30). If you want to be able to run tests, you need to get JavaCall.jl by running
```julia
Pkg.clone("https://github.com/samuel-massinon-invenia/JavaCall.jl.git")
Pkg.checkout("JavaCall", "pull-request/bf8b4987")
```

### Code Coverage

There are parts of the code that are not executed when running the basic test. This is because the Mock Server does not support ssl and we cannot run effective tests for those lines of code.

There are however separate tests for ssl. That requires setting up a local FTP server and following the steps above.

## Troubleshoot

### Downloaded files are unusable

Try downloading file in both binary and ASCII mode to see if one of the files is usable. 

### Other issues

Please add any other problem or bugs to the issues page.
