#!/bin/sh
# Shows one of the island's events right away and keeps it up until you hide it,
# so you don't have to wait for it. Developer builds only (`cd builder && cargo run`).
#
#   ./preview.sh music             show a made-up track playing (art + equalizer)
#   ./preview.sh next | previous   flip to the next / previous made-up track
#   ./preview.sh charging          show the bolt + battery ring
#   ./preview.sh lowBattery        show the "20% Battery" alert
#   ./preview.sh lock              show the lock-screen lock icon, over the desktop
#   ./preview.sh hide music        hide one again (what's really playing comes back)
#   ./preview.sh hide              hide them all
#   ./preview.sh settings          open Settings
events="music charging lowBattery lock"
usage() {
	echo "usage: ./preview.sh [hide] music | charging | lowBattery | lock" >&2
	echo "       ./preview.sh next | previous | hide | settings" >&2
	exit 1
}
case "$1" in
	music | charging | lowBattery | lock) open -g "hevel://preview/$1" ;;
	next | previous) open -g "hevel://track/$1" ;;
	hide)
		case "$2" in
			"") for event in $events; do open -g "hevel://hide/$event"; done ;;
			music | charging | lowBattery | lock) open -g "hevel://hide/$2" ;;
			*) usage ;;
		esac
		;;
	settings) open -g "hevel://settings" ;;
	*) usage ;;
esac
