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

Author
------

[Atsushi Nagase]

License
-------

[MIT License]

[Atsushi Nagase]: http://ngs.io/
[MIT License]: LICENSE
