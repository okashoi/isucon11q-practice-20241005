.PHONY: *

gogo: stop-services build truncate-logs start-services

stop-services:
	sudo systemctl stop nginx
	sudo systemctl stop isucondition.go.service
	ssh isucon-s2 "sudo systemctl stop isucondition.go.service"
	ssh isucon-s3 "sudo systemctl stop mysql"

build:
	$(MAKE) -C go
	scp go/isucondition isucon-s2:webapp/go/


truncate-logs:
	sudo journalctl --vacuum-size=1K
	sudo truncate --size 0 /var/log/nginx/access.log
	sudo truncate --size 0 /var/log/nginx/error.log
	ssh isucon-s3 "sudo truncate --size 0 /var/log/mysql/mysql-slow.log && sudo chmod 666 /var/log/mysql/mysql-slow.log"
	ssh isucon-s3 "sudo truncate --size 0 /var/log/mysql/error.log"

start-services:
	ssh isucon-s3 "sudo systemctl start mysql"
	ssh isucon-s2 "sudo systemctl start isucondition.go.service"
	sudo systemctl start isucondition.go.service
	sudo systemctl start nginx

kataribe: timestamp=$(shell TZ=Asia/Tokyo date "+%Y%m%d-%H%M%S")
kataribe:
	mkdir -p ~/kataribe-logs
	sudo cp /var/log/nginx/access.log /tmp/last-access.log && sudo chmod 0666 /tmp/last-access.log
	cat /tmp/last-access.log | kataribe -conf kataribe.toml > ~/kataribe-logs/$$timestamp.log
	cat ~/kataribe-logs/$$timestamp.log | grep --after-context 20 "Top 20 Sort By Total"
	cat ~/kataribe-logs/$$timestamp.log | grep --after-context 20 "Top 20 Sort By Total" > output.txt
	gh issue comment 1 --body "$$(echo '```'; cat output.txt; echo '```')"

pprof: TIME=60
pprof: PROF_FILE=~/pprof.samples.$(shell TZ=Asia/Tokyo date +"%H%M").$(shell git rev-parse HEAD | cut -c 1-8).pb.gz
pprof:
	curl -sSf "http://localhost:6060/debug/fgprof?seconds=$(TIME)" > $(PROF_FILE)
	go tool pprof $(PROF_FILE)
