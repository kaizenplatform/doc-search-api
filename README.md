# doc-search-api

Web API to Search Documentations from Middleman Site

[![Circle CI](https://circleci.com/gh/kaizenplatform/doc-search-api/tree/master.svg?style=svg&circle-token=26b2fc49c822c2255a676138f6defae6d30c467c)](https://circleci.com/gh/kaizenplatform/doc-search-api/tree/master)

[![Deploy](https://www.herokucdn.com/deploy/button.png)](https://heroku.com/deploy)

## Requirements

- Redis
- node

## Configuration

- `TOKEN_SECRET`
- `NODE_ENV`
- `SITEMAP_URL`

## Testing

```bash
npm test
```

## Start server

```
npm start
```

## Endpoints

### Search

```
GET /?q=...&lang=ja
```

### Trigger rebuild index

```
POST /rebuild -d 'token=...&timestamp=...'
```

## Example

### Triggering rebuild from Rake task

```rb
desc 'Request rebuilding search index'
task :rebuild_sitemap => [:env] do
  if api_base = ENV['DOC_SEARCH_API_BASE']
    require 'digest/sha1'
    require 'json'
    secret = ENV['REBUILD_TOKEN_SECRET']
    ts = (Time.now.to_f * 1000).to_i.to_s
    token = Digest::SHA1.hexdigest ts + secret
    res = %x{curl -XPOST #{api_base}/rebuild -d 'token=#{token}&timestamp=#{ts}'}
    json = JSON.parse res
    raise json['message'] if json['message']
  end
end
```

Author
------

[Atsushi Nagase]

License
-------

[MIT License]

[Atsushi Nagase]: http://ngs.io/
[MIT License]: LICENSE
