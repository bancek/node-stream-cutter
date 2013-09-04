stream = require('stream')

class Duplex extends stream.Transform
  _transform: (chunk, encoding, cb) ->
    @push(chunk)
    cb()

class StreamCutter extends stream.Transform
  constructor: (chunkSize) ->
    super()

    @chunkSize = chunkSize

    # has cutter source finished
    @done = no

    # reminder buffer for next stream
    @remainder = null

    # current output stream
    @currentStream = null

    @error = null

    @on 'end', =>
      @done = yes

      # end has been emitted after all data has been transfered
      if @_readableState.buffer.length == 0 and not @remainder
        @_endCurrentStream()

    # propagate error to currentStream
    @on 'error', (err) =>
      if @currentStream
        @currentStream.emit 'error', err
      else
        @error = err

  _createNextStream: =>
    # create next output stream
    @currentStream = new Duplex()
    # reset current read counter
    @currentRead = 0

    # end must be false. @remainder may not get read if it's true
    @pipe(@currentStream, end: no)

    # if error was received and currentStream has been null
    if @error?
      err = @error
      @error = null

      process.nextTick =>
        @currentStream?.emit('error', err)

  _endCurrentStream: =>
    process.nextTick =>
      # _endCurrentStream could be called multiple times
      if @currentStream?
        # end current output stream and unpipe
        currentStream = @currentStream
        @currentStream = null

        currentStream.end()
        @unpipe()
    , 0

  _transform: (chunk, encoding, done) =>
    # just push data through
    @push(chunk)
    done()

  read: (size) =>
    # source finished and no data left in @reminder buffer
    if @done and not @remainder?
      @_endCurrentStream()
      return null

    return null if not @currentStream? # waiting for nextStream
    return new Buffer(0) if size is 0 # empty read

    if @currentRead == @chunkSize
      # waiting for next stream to reset currentRead
      return null

    if @remainder?
      # first read of new stream
      data = @remainder
      @remainder = null
    else
      # no data in reminder, call super
      data = super

    return null if not data?

    len = data.length

    if @currentRead + len < @chunkSize
      # whole chunk can go into current stream
      @currentRead += len

      if @done
        # this was the last chunk before end and there is no remainder
        @_endCurrentStream()

      data
    else
      # chunk is too big for current stream so we need to slice it
      acceptedLen = @chunkSize - @currentRead
      accepted = data.slice(0, acceptedLen)

      # set current read to chunk size so we know we can't accept any more data
      @currentRead = @chunkSize

      @remainder = data.slice(acceptedLen)

      process.nextTick =>
        @_endCurrentStream()

      accepted

  nextStream: =>
    # we could receive end event but still have remainder
    if not @done or @remainder?
      # console.log 'next'
      @_createNextStream()
      @currentStream
    else
      null

module.exports = StreamCutter
