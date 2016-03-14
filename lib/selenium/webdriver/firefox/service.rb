# encoding: utf-8
#
# Licensed to the Software Freedom Conservancy (SFC) under one
# or more contributor license agreements.  See the NOTICE file
# distributed with this work for additional information
# regarding copyright ownership.  The SFC licenses this file
# to you under the Apache License, Version 2.0 (the
# "License"); you may not use this file except in compliance
# with the License.  You may obtain a copy of the License at
#
#   http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing,
# software distributed under the License is distributed on an
# "AS IS" BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY
# KIND, either express or implied.  See the License for the
# specific language governing permissions and limitations
# under the License.

module Selenium
  module WebDriver
    module Firefox

      #
      # @api private
      #

      class Service < WebDriver::Service
        DEFAULT_PORT = 4444
        MISSING_TEXT = "Unable to find Mozilla Wires. Please download the executable from https://github.com/jgraham/wires/releases"

        def self.executable_path
          @executable_path ||= (
            path = Platform.find_binary "wires"
            path or raise Error::WebDriverError, MISSING_TEXT
            Platform.assert_executable path

            path
          )
        end

        def self.default_service(*extra_args)
          new executable_path, DEFAULT_PORT, *extra_args
        end

        private

        def start_process
          server_command = [@executable_path, "--binary=#{Firefox::Binary.path}", "--webdriver-port=#{@port}", *@extra_args]
          @process       = ChildProcess.build(*server_command)

          if $DEBUG == true
            @process.io.inherit!
          elsif Platform.windows?
            # workaround stdio inheritance issue
            # https://github.com/jgraham/wires/issues/48
            @process.io.stdout = @process.io.stderr = File.new(Platform.null_device, 'w')
          end

          @process.start
        end

        def stop_process
          super
          if Platform.windows? && !$DEBUG
            @process.io.close rescue nil
          end
        end

        def stop_server
          Net::HTTP.start(@host, @port) do |http|
            http.open_timeout = STOP_TIMEOUT / 2
            http.read_timeout = STOP_TIMEOUT / 2

            http.head("/shutdown")
          end
        end

        def connect_until_stable
          @socket_poller = SocketPoller.new @host, @port, START_TIMEOUT

          unless @socket_poller.connected?
            raise Error::WebDriverError, "unable to connect to Mozilla Wires #{@host}:#{@port}"
          end
        end

      end # Service
    end # Firefox
  end # WebDriver
end # Selenium
