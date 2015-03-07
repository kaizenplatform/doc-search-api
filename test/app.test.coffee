expect = require 'expect.js'
sinon = require 'sinon'
nock = require 'nock'
request = require 'supertest'
process.env.LOG = require('path').resolve __dirname, '../log/test.access.log'

describe 'app', ->
  app = subject = params = currentTimestamp = timestamp = token = nockScope = sitemapJSON = query = null
  isExpected = -> expect subject()

  beforeEach ->
    app = require '../app.coffee'
    currentTimestamp = -> 1425648528777
    timestamp = -> currentTimestamp()
    sinon.stub app, 'getTimestamp', -> currentTimestamp()
    process.env.NODE_ENV = 'test'
    process.env.TOKEN_SECRET = 'asdf1234'
    process.env.SITEMAP_URL = 'http://mydoc.com/sitemap.json'
    token = -> '35f03fc0095c27592901a97d3c76b44ecfa81136'
    sitemapJSON = ->
      en: [
        { url: '/en/test/content1', title: 'Content 1', description: 'Content 1 Desc', body: 'Content 1 Body' }
        { url: '/en/test/content2', title: 'Content 2', description: 'Content 2 Desc', body: 'Content 2 Body' }
        { url: '/en/test/content3', title: 'Content 3', description: 'Content 3 Desc', body: 'Content 3 Body' }
      ]
      ja: [
        { url: '/ja/test/content1', title: 'Content 1', description: 'Content 1 Desc', body: 'Content 1 Body' }
        { url: '/ja/test/content2', title: 'Content 2', description: 'Content 2 Desc', body: 'Content 2 Body' }
        { url: '/ja/test/content3', title: 'Content 3', description: 'Content 3 Desc', body: 'Content 3 Body' }
      ]
    nock.disableNetConnect()
    nock.enableNetConnect '127.0.0.1'
    nockScope = nock('http://mydoc.com')
      .get '/sitemap.json'
      .reply 200, -> sitemapJSON()

  afterEach ->
    do app.getTimestamp.restore
    do nock.cleanAll
    process.removeAllListeners 'uncaughtException'

  describe 'helpers', ->
    describe 'createToken', ->
      beforeEach ->
        subject = -> app.createToken()
      it 'creates token from timestamp', ->
        isExpected().to.eql token()
      describe 'passing argument', ->
        beforeEach ->
          subject = -> app.createToken 1425648528778
        it 'creates different token', ->
          isExpected().to.eql 'd6c29504b1d2600921eb0ee9c80fd17f4763a554'
    describe 'validateToken', ->
      beforeEach ->
        subject = -> app.validateToken token(), timestamp()
      describe 'valid', ->
        it 'returns true', ->
          isExpected().to.be yes
      describe 'invalid', ->
        beforeEach ->
          token = -> 'foo'
        it 'returns false', ->
          isExpected().to.be no
      describe 'timeout', ->
        beforeEach ->
          timestamp = -> currentTimestamp() + 30001
        it 'returns false', ->
          isExpected().to.be no
    describe 'importSitemap', ->
      beforeEach -> app.importSitemap sitemapJSON()
      it 'imports with keys by locale', (done) ->
        app.redis.keys 'doc:test:*', (err, res) ->
          subject = -> res.sort()
          try
            isExpected().to.eql ['doc:test:en', 'doc:test:ja']
            do done
          catch e
            done e
      it 'imports sitemap (en)', (done) ->
        app.redis.smembers 'doc:test:en', (err, res) ->
          subject = -> res.sort()
          try
            isExpected().to.eql [
              '/en/test/content1\tContent 1\tcontent 1\tcontent 1 desc\tcontent 1 body'
              '/en/test/content2\tContent 2\tcontent 2\tcontent 2 desc\tcontent 2 body'
              '/en/test/content3\tContent 3\tcontent 3\tcontent 3 desc\tcontent 3 body'
            ]
            do done
          catch e
            done e
      it 'imports sitemap (ja)', (done) ->
        app.redis.smembers 'doc:test:ja', (err, res) ->
          subject = -> res.sort()
          try
            isExpected().to.eql [
              '/ja/test/content1\tContent 1\tcontent 1\tcontent 1 desc\tcontent 1 body'
              '/ja/test/content2\tContent 2\tcontent 2\tcontent 2 desc\tcontent 2 body'
              '/ja/test/content3\tContent 3\tcontent 3\tcontent 3 desc\tcontent 3 body'
            ]
            do done
          catch e
            done e

    describe 'searchSitemap', ->
      beforeEach -> app.importSitemap sitemapJSON()
      it 'callbacks single page',(done)  ->
        app.searchSitemap 'en', 'tENt 1', (err, res) ->
          try
            expect(err).to.be null
            expect(res).to.eql [
              { url: '/en/test/content1', title: 'Content 1' }
            ]
            do done
          catch e
            done e

      it 'callbacks multiple pages',(done)  ->
        app.searchSitemap 'ja', 'tENt', (err, res) ->
          try
            expect(err).to.be null
            expect(res).to.eql [
              { url: '/ja/test/content1', title: 'Content 1' }
              { url: '/ja/test/content2', title: 'Content 2' }
              { url: '/ja/test/content3', title: 'Content 3' }
            ]
            do done
          catch e
            done e

  describe 'routing', ->
    describe 'GET /', ->
      beforeEach ->
        query = -> '?q=tENt&lang=ja'
        subject = -> request(app).get "/#{query()}"
      describe 'missing parameter', ->
        beforeEach ->
          query = -> ''
        it 'responses bad request', (done) ->
          subject()
            .expect message: 'Missing parameters: q, lang'
            .expect 400
            .end done
      it 'responses ok', (done) ->
        subject()
          .expect [
              { url: '/ja/test/content1', title: 'Content 1' }
              { url: '/ja/test/content2', title: 'Content 2' }
              { url: '/ja/test/content3', title: 'Content 3' }
            ]
          .expect 200
          .end done

    describe 'POST /rebuild', ->
      beforeEach ->
        params = -> token: token(), timestamp: timestamp()
        subject = ->
          request(app).post('/rebuild').send params()
      it 'responses bad request', (done) ->
        token = -> 'foo'
        subject()
          .expect message: 'Invalid token'
          .expect 400
          .end done
      it 'responses ok', (done) ->
        sitemap = null
        sinon.stub app, 'importSitemap', (_sitemap) => sitemap = _sitemap
        subject()
          .expect success: yes
          .expect 200
          .end ->
            expect(sitemap).to.eql sitemapJSON()
            app.importSitemap.restore()
            do done

