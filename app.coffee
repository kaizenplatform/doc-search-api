require('dotenv').load()
bodyParser = require('body-parser')
cors = require 'cors'
crypto = require 'crypto'
express = require 'express'
fs = require 'fs'
http = require 'http'
morgan = require 'morgan'
request = require 'request'

TOKEN_TIMEOUT = 60000

_redis = require('redis')
_redis.debug_mode = process.env.REDIS_DEBUG == '1'

if uriString = process.env.REDISTOGO_URL || process.env.BOXEN_REDIS_URL
  uri = require('url').parse uriString
  redis = _redis.createClient uri.port, uri.hostname
  redis.auth uri.auth?.split(':')?[1]
else
  redis = _redis.createClient()

app = do express
app.redis = redis
app.use bodyParser.json()
app.use bodyParser.urlencoded extended: yes
app.use cors
  credentials: yes
  allowedHeaders: ['Origin', 'X-Requested-With', 'Content-Type', 'Accept', 'Authorization']
  origin: (origin, callback) -> callback null, yes
morganOpts = {}
if log = process.env.LOG
  morganOpts.stream = fs.createWriteStream log, flags: 'a'
app.use morgan 'combined', morganOpts

app.getTimestamp = -> new Date().getTime()

app.createToken = (ts = @getTimestamp())->
  secret = process.env.TOKEN_SECRET
  shasum = crypto.createHash 'sha1'
  shasum.update ts + secret, 'utf8'
  shasum.digest 'hex'

app.validateToken = (token, timestamp) ->
  return no if @getTimestamp() - timestamp > TOKEN_TIMEOUT
  @createToken(timestamp) is token

app.importSitemap = (sitemap) ->
  env = process.env.NODE_ENV || 'development'
  for lang, pages of sitemap
    key = "doc:#{env}:#{lang}"
    redis.del key
    set = [key]
    for {url, description, title, body} in pages
      set.push [url, title, ''].join("\t") + [title, description, body].join("\t").toLowerCase()
    redis.sadd set, redis.print

app.searchSitemap = (lang, query, callback) ->
  env = process.env.NODE_ENV || 'development'
  key = "doc:#{env}:#{lang}"
  redis.sscan [key, 0, 'MATCH', "*#{query.toLowerCase()}*", 'COUNT', 1000], (err, res) ->
    return callback err, null if err?
    pages = []
    for item in res[1].sort()
      [url, title] = item.split '\t'
      if url && title
        pages.push { url, title }
    callback null, pages

app.get '/', (req, res) ->
  {lang, q} = req.query
  missings = []
  for k in ['q', 'lang']
    missings.push k unless req.query[k]
  if missings.length > 0
    res.status(400).json message: "Missing parameter#{ if missings.length > 1 then 's' else '' }: #{ missings.join ', ' }"
    return
  app.searchSitemap lang, q, (err, pages)->
    if err?
      res.status(400).json message: err.message
      return
    res.json pages

app.post '/rebuild', (req, res) ->
  {token,timestamp} = req.body
  unless app.validateToken token, timestamp
    res.status(400).json message: 'Invalid token'
    return
  unless url = process.env.SITEMAP_URL
    console.error 'SITEMAP_URL is not configured'
    res.status 500
    return
  request.get {url, json: yes}, (e, r, json) ->
    app.importSitemap json
    res.json success: yes

module.exports = app

unless module.parent?
  app.listen process.env.PORT || 3000
