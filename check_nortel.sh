#!/bin/bash

DEBUG=false
#some config variables
SNMP_VERSION='2c'
SNMP_COMMUNITY='PUBLIC'
SNMP_OTHER='-O uq -t 3'

OK=0; WARNING=1; CRITICAL=2; UNKNOWN=3;
SNMP=$( which snmpwalk )
INTERFACES=( );

function snmp_get()
{
	if [ -z $1 ] || [ -z $2 ];then
		return 255
	fi
	HOST=$1
	OID=$2

	( $DEBUG ) && echo "DEBUG: Executing snmpwalk with these options: $SNMP_OTHER" 1>&2
	SNMP_OUT=$( $SNMP $SNMP_OTHER -v$SNMP_VERSION -c $SNMP_COMMUNITY $HOST $OID 2>&1 );
	if [[ ! "$SNMP_OUT" =~ '^Timeout' ]] && [ $? -eq 0 ];then
		echo $SNMP_OUT
	else
		echo "CRITICAL: $SNMP_OUT"
		return $CRITICAL
	fi
	return $OK;
}

function ping()
{
	OID='system.sysDescr.0'

	OUTPUT=`snmp_get $SNMP_HOST $OID`
	OUT_CODE=$?
	
	if [ $OUT_CODE -eq 0 ];then
		echo -n "OK: ";
		OUTPUT=$( echo $OUTPUT | sed -r 's/^[^ ]*? (.+)/\1/g' )
	fi
	echo $OUTPUT
	return $OUT_CODE
}

function get_interfaces()
{
	OUTPUT=`snmp_get $SNMP_HOST interfaces.ifTable.ifEntry.ifIndex`
	for i in $OUTPUT;do
		if [[ "$i" =~ '^[0-9]+$' ]];then
			INT_OUT=$( snmp_get $SNMP_HOST interfaces.ifTable.ifEntry.ifDescr.$i );
			INT_NAME=$( echo $INT_OUT | sed -r 's/.+ (.+?)$/\1/' )
			INTERFACES[i]=$INT_NAME;
		fi
	done
}

function traffic()
{
	if [ -z $1 ] || [ -z $2 ];then
		return 255
	fi
	W_T=$1
	C_T=$2
	
	OUT=$OK

	NUM_INT=$( snmp_get $SNMP_HOST interfaces.ifNumber | sed -r 's/.* ([0-9]+)$/\1/' )
	if [[ "$NUM_INT" =~ '^CRITICAL' ]];then
		echo $NUM_INT
		return $CRITICAL
	fi
	get_interfaces
	for n in `seq 0 $NUM_INT`;do
		if [ -n "${INTERFACES[n]}" ];then
			OUT_ERRORS=$( snmp_get $SNMP_HOST interfaces.ifTable.ifEntry.ifOutErrors.$n | cut -d" " -f2)
			IN_ERRORS=$( snmp_get $SNMP_HOST interfaces.ifTable.ifEntry.ifInErrors.$n | cut -d" " -f2)

			if (( $IN_ERRORS >= $W_T ));then
				if (( $IN_ERRORS >= $C_T ));then
					echo "CRITICAL: Interface "${INTERFACES[n]}" with IN errors: $IN_ERRORS"
					OUT=$CRITICAL
				else
					echo "WARNING: Interface "${INTERFACES[n]}" with IN errors: $IN_ERRORS"
					[ "$OUT" -eq "$OK" ] && OUT=$WARNING
				fi
			fi 
			if (( $OUT_ERRORS >= $W_T ));then
				if (( $OUT_ERRORS >= $C_T ));then
					echo "CRITICAL: Interface "${INTERFACES[n]}" with OUT errors: $OUT_ERRORS"
					OUT=$CRITICAL
				else
					echo "WARNING: Interface "${INTERFACES[n]}" with OUT errors: $OUT_ERRORS"
					[ "$OUT" -eq "$OK" ] && OUT=$WARNING
				fi
			fi 
		fi
	done

	if [ "$OUT" -eq "$OK" ];then
		echo "OK: All interfaces are OK"
	fi
	return $OUT
}

function usage()
{
	cat <<USAGE
Usage: $0 <hostname|ip> <action> (critical|warning)
Actions:
	* ping
	* traffic (w|c)
USAGE
	exit $UNKNOWN
	
}

if [ $# -lt 2 ] || [[ $1 =~ '^-[hu]$' ]];then
	usage
else
	SNMP_HOST=$1
	SNMP_ACTION=$2
	[[ "$SNMP_ACTION" =~ '([A-Z])' ]] && SNMP_ACTION=$( echo $SNMP_ACTION | tr 'A-Z' 'a-z' );
fi

if [ ! -e "$SNMP" ];then
	echo "Is snmpwalk installed? Edit this and specify the path."
	exit $UNKNOWN
fi

case $SNMP_ACTION in
	"ping")
		ping
		;;
	"traffic")
		if [ -z "$1" ] || [ -z "$2" ];then
			usage
		fi
		WARN=$3
		CRIT=$4
		( $DEBUG ) && echo "DEBUG: WARNING=$WARNING CRITICAL=$CRITICAL"
		traffic $WARN $CRIT
		;;
	*)
		usage
		;;
esac
exit $?
