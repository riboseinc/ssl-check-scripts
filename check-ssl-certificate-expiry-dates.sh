#!/bin/bash
#
# check-ssl-certificate-expiry-dates.sh by ebo@
#
# This script checks the expiry date of SSL certificates on webservers.
#
# Written and tested on RHEL 7.4, CentOS 7.4 and macOS High Sierra.
#
# Dependencies for RHEL:
# 1. OpenSSL
# 2. Coreutils (for timeout)
#
# Dependencies for macOS:
# 1. Brew
# 2. OpenSSL (from Brew, because of macOS has an outdated OpenSSL)
# 3. Coreutils (from Brew, for gtimeout)
#
# Usage:
# ./checkssl.sh <grace period in days> <host1:port> [hostN:port]
#
# Example run:
# $ ./check-ssl-certificate-expiry-date.sh 31 test1.com:443 test2.com:443
# [WARNING] test1.com:443 certificate will expire at: Apr 14 12:00:00 2018 GMT
# [GOOD] test2.com:443 certificate will expire at: Mar 26 12:00:00 2020 GMT
#
# Return codes:
# 0: no certificates are not going to expire
# 1: some (or all) certificates are going to expire

readonly export __progname="$(basename $0)"

# operating system dependent locations
readonly export openssllnx="/usr/bin/openssl"
readonly export timeoutlnx="/usr/bin/timeout"
readonly export opensslmac="/usr/local/opt/openssl/bin/openssl"
readonly export timeoutmac="/usr/local/bin/gtimeout"
readonly export uname="/usr/bin/uname"

errx() {
	echo -e "${__progname}: $@" >&2

	exit 1
}

usage() {
	echo -n "usage: ${__progname} "
	echo -n "<grace period in days> "
	echo -n "<host1:port> "
	echo "[hostN:port]"

	exit 1
}

checkgraceperiod() {
	[[ ! "$1" =~ ^-?[0-9]+$ || \
		"$1" -le 0 || \
		"$1" -gt 365 ]] && \
			errx "${FUNCNAME[0]}() invalid grace period '$1'"

	return 0
}

checkos() {
	readonly local rhrel="/etc/redhat-release"

	[ ! -x "${uname}" ] && \
		errx "${FUNCNAME[0]}() cannot execute '${uname}'"

	"${uname}" | grep -q ^Darwin
	if [ $? -eq 0 ]; then
		export openssl="${opensslmac}"
		export timeout="${timeoutmac}"

		return 0
	elif [ -f "${rhrel}" ]; then
		export openssl="${openssllnx}"
		export timeout="${timeoutlnx}"

		return 0
	fi

	errx "unsupported operating system"
}

checkdependencies() {
	for dependency in "${openssl}" "${timeout}"; do
		[ ! -x "${dependency}" ] && \
			errx "${FUNCNAME[0]}() cannot execute '${dependency}'"
	done
}

checksslcertificate() {
	if [ -z "$2" ]; then
		echo "${FUNCNAME[0]}() missing parameter(s)"

		return 1
	fi

	local host="${1%:*}"

	# verify the port
	local port="${1#*:}"
	if [[ ! "${port}" =~ ^-?[0-9]+$ || \
		"${port}" -le 0 || \
		"${port}" -gt 65535 ]]; then
			echo "${FUNCNAME[0]}() invalid or missing port for '$1'"

			return 1
	fi

	# obtain the SSL certificate
	local sslcert="$(echo | \
			"${timeout}" 10 \
			"${openssl}" s_client \
			-connect "${host}:${port}" 2>/dev/null)"
	if [ -z "${sslcert}" ]; then
		echo "${FUNCNAME[0]}() '$1' cannot fetch SSL certificate"

		return 1
	fi

	# obtain the certificate expiry date
	local sslexpirydate="$(echo "${sslcert}" | \
			"${openssl}" x509 \
			-noout \
			-enddate 2>/dev/null | \
			cut -d '=' -f 2)"
	if [ -z "${sslexpirydate}" ]; then
		echo "${FUNCNAME[0]}() '$1' cannot get certificate expiry date"

		return 1
	fi

	# convert the grace period to seconds and check this against the end
	# date of the certificate
	local graceperiodseconds="$[$2 * 24 * 3600]"
	echo "${sslcert}" | \
		"${openssl}" x509 \
		-checkend "${graceperiodseconds}" \
		-noout
	if [ $? -ne 0 ]; then
		echo "[WARNING] '$1' certificate expires on: ${sslexpirydate}"

		return 1
	fi

	echo "[GOOD] '$1' certificate expires on: ${sslexpirydate}"

	return 0
}

main() {
	local ret="0"

	[ -z "$2" ] && \
		usage

	# grace period in days
	readonly local graceperioddays="$1"

	# verify the grace period
	checkgraceperiod "${graceperioddays}"

	# ensure we're on RHEL/CentOS or macOS
	checkos

	# ensure OpenSSL and timeout is available
	checkdependencies

	shift
	for host in $@; do
		checksslcertificate "${host}" "${graceperioddays}" || \
			ret="1"
	done

	return "${ret}"
}

main "$@"

exit $?
