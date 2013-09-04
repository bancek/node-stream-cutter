assert = require('assert')
should = require('chai').should()
fs = require('fs')
os = require('os')
nodePath = require('path')
rmdir = require('rimraf')
StreamCutter = require('../src')

getTmp = ->
  tmpName = Math.random().toString(36).substr(2, 5)
  nodePath.join(os.tmpDir(), tmpName)

writeRandomContent = (file, size) ->
  partSize = Math.min(4 * 1024 * 1024, size)

  fs.writeFileSync(file, '')

  while size > 0
    fs.appendFileSync(file, new Buffer(Math.min(partSize, size)))
    size -= partSize

describe 'StreamCutter', ->
  [
    100 * 1024 * 1024,
    10 * 1024 * 1024,
    1 * 1024 * 1024,
    100 * 1024,
    65 * 1024,
    10 * 1024,
    1 * 1024,
    100,
    10,
    1
  ].forEach (totalSize) ->
    tmp = null
    tmpFile = null
    tmpOut = null

    before ->
      tmp = getTmp()
      tmpFile = nodePath.join(tmp, 'test.bin')
      tmpOut = nodePath.join(tmp, 'out')

      fs.mkdirSync(tmp)

      writeRandomContent(tmpFile, totalSize)

    after (done) ->
      rmdir(tmp, done)

    [
      13333337, # 13MB - more than whole file (for 10M)
      1333337, # 1.3MB
      70000, # 70k - more than one chunk size, less than two
      20000 # 20k - less than one chunk
    ].forEach (chunkSize) ->
      describe 'cut', ->
        beforeEach ->
          fs.mkdirSync(tmpOut)

        afterEach (done) ->
          rmdir(tmpOut, done)

        it "should cut stream (#{totalSize} total, #{chunkSize} chunk)", (done) ->
          totalWritten = 0

          writeFile = (name, stream, cb) ->
            out = fs.createWriteStream name

            stream.pipe(out)

            out.on 'close', ->
              totalWritten += out.bytesWritten
              cb()

          s = fs.createReadStream tmpFile

          s.on 'open', ->
            cutter = new StreamCutter(chunkSize)

            s.pipe(cutter)

            i = 0

            next = ->
              i += 1

              stream = cutter.nextStream()

              if stream?
                filename = nodePath.join(tmpOut, 'out_' + i)

                writeFile filename, stream, ->
                  process.nextTick ->
                    next()
                  , 0
              else
                totalWritten.should.equal totalSize

                files = fs.readdirSync(tmpOut)

                files.length.should.equal Math.ceil(totalSize / chunkSize)

                fileSizes = files.map (file) ->
                  [file, fs.statSync(nodePath.join(tmpOut, file)).size]

                lastName = 'out_' + Math.ceil(totalSize / chunkSize)

                otherFiles = fileSizes.filter(([file, size]) -> file != lastName)

                otherFiles.forEach ([file, size]) ->
                  size.should.equal chunkSize

                lastFile = fileSizes.filter(([file, size]) -> file == lastName)[0]

                lastFile[1].should.equal totalSize % chunkSize

                done()

            next()
