assert = require('assert')
should = require('chai').should()
fs = require('fs')
os = require('os')
crypto = require('crypto')
nodePath = require('path')
request = require('request')
rmdir = require('rimraf')
StreamCutter = require('../src')

request = request.defaults(proxy: process.env.HTTP_PROXY or process.env.http_proxy)

hashArray = (arr) ->
  md5sum = crypto.createHash('md5')

  arr.forEach (txt) ->
    md5sum.update(txt)

  md5sum.digest('hex')

describe 'StreamCutter', ->
  it "should download Node.js source and cut it into equally sized files", (done) ->
    tmp = nodePath.join(__dirname, '..', 'tmp')

    if fs.existsSync(tmp)
      rmdir.sync(tmp)

    fs.mkdirSync(tmp)

    req = request('http://nodejs.org/dist/v0.10.17/node-v0.10.17.tar.gz')

    cutter = new StreamCutter(1 * 1024 * 1024)

    req.pipe(cutter)

    i = 0

    next = ->
      i += 1

      stream = cutter.nextStream()

      if stream?
        filename = nodePath.join(tmp, 'part_' + i)

        out = fs.createWriteStream filename

        out.on 'close', ->
          process.nextTick ->
            next()
          , 0

        stream.pipe(out)
      else
        parts = [1..14].map (x) -> 'part_' + x
        content = parts.map (x) -> fs.readFileSync(nodePath.join(tmp, x))
        hashes = content.map (x) -> hashArray([x])
        hash = hashArray(content)

        hashes.should.eql [
          'f1219bcdd192fbf8c1a5d858491e0392'
          '74fa0968e7886d927fcd2d6162e637d2'
          '0866b4ace15ef2650adde06cbb4e841d'
          '70499eede60cddce3376cd6ce6669020'
          'fb3d7e78af54bdadce2b62929ee2e85d'
          '09a2d7689c86c346f361fbae78af8761'
          '289fac2fbdfaa00dac040b6a626c8cb4'
          'c1c05d79b4eddf23f7b6d6f0e5b3739b'
          'cad077e1d25c36d6305d8c2dcfd949ec'
          'dcc9f8e49582dc043cb2f3aacd33716d'
          'e7fbeb80c4f4f6020ac733fcbc12633c'
          'bdc4db5db54515f89d60274d7eab7cdf'
          'ad61cf01953c9101e27dfa16f8779ba7'
          'edacd280b1ce703de573f3edb023fcf4'
        ]

        hash.should.equal 'a2b05af77e8e3ef3b4c40a68372429f1'

        rmdir.sync(tmp)

        done()

    next()
