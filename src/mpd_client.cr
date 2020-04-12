class MPDClient
  getter client

  def initialize(@sockets : Array(HTTP::WebSocket))
    MPD::Log.level = :error
    MPD::Log.backend = ::Log::IOBackend.new

    # @client = MPD::Client.new("localhost", 6600, with_callbacks: true)
    @client = MPD::Client.new("/run/mpd/socket", with_callbacks: true)
    @client.callbacks_timeout = 100.milliseconds

    @client.on :song do |_song|
      if song = current_song
        data = {"action" => "song", "song" => song}

        SOCKETS.each { |socket| socket.send(data.to_json) }
      end
    end

    @client.on :state do |state|
      data = {"action" => "state", "state" => state}

      SOCKETS.each { |socket| socket.send(data.to_json) }
    end

    @client.on :random do |random|
      data = {"action" => "random", "state" => random}

      SOCKETS.each { |socket| socket.send(data.to_json) }
    end

    @client.on :repeat do |repeat|
      data = {"action" => "repeat", "state" => repeat}

      SOCKETS.each { |socket| socket.send(data.to_json) }
    end

    @client.on :single do |single|
      data = {"action" => "single", "state" => single}

      SOCKETS.each { |socket| socket.send(data.to_json) }
    end

    @client.on :time do |time|
      time = time.split(':')
      data = {"action" => "time", "current" => time[0], "full" => time[1]}

      SOCKETS.each { |socket| socket.send(data.to_json) }
    end
  end

  def current_song : String?
    if current_song = client.currentsong
      current_song.to_json
    end
  end

  def toggle_play_pause
    status.try do |status|
      case status["state"]
      when "play"
        pause
      when "pause", "stop"
        play
      else
        nil
      end
    end
  end

  def toggle_mode(mode)
    status.try do |status|
      state = status[mode] == "0"
      case mode
      when "random"
        random(state)
      when "repeat"
        repeat(state)
      when "single"
        single(state)
      else
        nil
      end
    end
  end

  # `relative` - from 0 to 1
  def set_song_position(relative : Float64)
    if current_song = client.currentsong
      time = current_song["Time"].to_i
      seekcur((time * relative).to_i)
    end
  end

  forward_missing_to @client
end
