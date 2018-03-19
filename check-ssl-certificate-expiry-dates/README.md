# Introduction

check-ssl-certificate-expiry-dates.sh is a script that checks the expiry date of
SSL certificates on webservers.


# Supported Platforms

Currently supported platforms:

* RHEL/CentOS 7
* macOS


# Usage

## Default

``` console
$ ./check-ssl-certificate-expiry-dates.sh
usage: check-ssl-certificate-expiry-dates.sh <grace period in days> <host1:port> [hostN:port]
```

## Example run with certificates that are not going to expire:

``` console
$ ./check-ssl-certificate-expiry-dates.sh 31 google.com:443 www.microsoft.com:443 www.oracle.com:443
[GOOD] 'google.com:443' certificate expires on: May 23 22:07:00 2018 GMT
[GOOD] 'www.microsoft.com:443' certificate expires on: Jan 16 21:24:02 2020 GMT
[GOOD] 'www.oracle.com:443' certificate expires on: Dec 15 12:00:00 2018 GMT
```

## Example run with some certificates that are going to expire:

``` console
$ ./check-ssl-certificate-expiry-dates.sh 31 test1.localdomain:443 test2.localdomain:443
[WARNING] 'test1.localdomain:443' certificate expires on: Apr 14 12:00:00 2018 GMT
[GOOD] 'test2.localdomain:443' certificate expires on: Nov  9 14:18:03 2018 GMT
```


# Return Codes

* 0: No certificates are not going to expire
* 1: Some (or all) certificates are going to expire


# Dependencies

## Dependencies for RHEL
1. OpenSSL
2. Coreutils (for `timeout`)

## Dependencies for macOS
1. Brew
2. OpenSSL (for `openssl` from Brew, because macOS has an outdated OpenSSL)
3. Coreutils (for `gtimeout` from Brew)
