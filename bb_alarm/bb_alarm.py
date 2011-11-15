#! /usr/local/bin/python

import binascii
import getpass
import glob
import optparse
import struct
import sys
import time
import urllib2

import serial
import simplejson as json


def scanports():
    return glob.glob('/dev/tty*')


if __name__ == '__main__':

    usage = 'usage: shakr [options]'
    parser = optparse.OptionParser(usage=usage)

    parser.add_option("-p", "--port",
                      dest="port",
                      default=None,
                      type="string",
                      help="the serial connection port [default: %default]",
                      metavar="PORT")
    parser.add_option("-b", "--baud",
                      dest="baud",
                      default=19200,
                      type="int",
                      help="the serial connection BAUD rate [default: %default]",
                      metavar="BAUD")
    parser.add_option("-t", "--timeout",
                      dest="timeout",
                      default=15,
                      type="int",
                      help="the serial connection TIMEOUT in seconds [default: %default]",
                      metavar="TIMEOUT")
    parser.add_option("-d", "--debug",
                      action="store_true",
                      dest="debug",
                      default=False,
                      help="the debug setting to print more information [default: %default]")
    (options, args) = parser.parse_args()

    # Set up the options
    PORT = options.port
    BAUD = options.baud
    TIMEOUT = options.timeout
    DEBUG = options.debug

    # Scan the ports if none given
    if not PORT:
        for port in scanports():
            if 'usbserial' in port or 'usbmodem' in port:
                PORT = port
                break
        if not PORT:
            print 'Port not found, please connect device or set before running'
            #sys.exit()

    if DEBUG:
        print 'PORT %s' % PORT
        print 'BAUD %s' % BAUD
        print 'TIMEOUT %s' % TIMEOUT

    # Connect to serial port and wait for arduino reboot and startup
    try:
        ser = serial.Serial(PORT, BAUD, timeout=TIMEOUT)
        time.sleep(10.0)
    except serial.SerialException, e:
        print 'Serial connection could not be established:\n\t', e
        # sys.exit()

    # Username and Password Input
    user = raw_input('Username: ')
    password = getpass.getpass()

    # Set up the build list
    build_list = [
        'full',
        'webapp-only',
        'twisted-only',
        'style',
        'javascript',
        'build_dist',
        'noit_merged',
        'noit_java_only_old_iep',
    ]
    while 1:
        build_status = {}

        for build in build_list:
            try:
                password_mgr = urllib2.HTTPPasswordMgrWithDefaultRealm()
                top_level_url = "https://reach-bb.k1k.me/json/builders/%s/builds?select=-1&select=-2&as_text=1" % build
                password_mgr.add_password(None, top_level_url, user, password)
                handler = urllib2.HTTPBasicAuthHandler(password_mgr)
                opener = urllib2.build_opener(handler)
                urllib2.install_opener(opener)
                page = urllib2.urlopen(top_level_url + 'waterfall').read()
                build_data = json.loads(page)
            except Exception, e:
                print e
                sys.exit()

            if 'text' in build_data['-1']:
                build_status[build] = build_data['-1']['text'][1]
            elif 'text' in build_data['-2']:
                build_status[build] = build_data['-2']['text'][1]
            else:
                build_status[build] = None

        for key in build_list:
            value = build_status[key]
            mag = 5.0
            if value == 'successful':
                mag = 5.0
            else:
                mag = 1.0
            print key, value, mag

            # Pack up the value and send it
            packed = struct.pack('f', mag)
            if DEBUG:
                print mag, binascii.hexlify(packed)

            try:
                ser.write(packed)

                time.sleep(5.0)

                # Confirm that value was received
                confirm = ser.readline()
                if DEBUG:
                    print confirm

            except Exception, e:
                print e

        # Wait 15 before polling
        time.sleep(15)
