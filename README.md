# pixiv-crawler
Crawl pixiv and post to pirage(private image uploader).

It works with random choiced proxy and async(depends EventMachine), so you can crawl pixiv quick and safe(but session id will steal by proxy servers).

## Que
Some scripts quening illust id to mongodb.
If you want to crawl new target, you write queing code.

## Fetch
`fetcher.rb` process job que.
