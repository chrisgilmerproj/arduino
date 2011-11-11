#! /usr/local/bin/python

import binascii
import glob
import optparse
import pprint
import struct
import sys
import time
import urllib
import urllib2

import serial

def scanports():
    return glob.glob('/dev/tty*')

if __name__ == '__main__':

    usage = 'usage: shakr [options]'
    parser = optparse.OptionParser(usage=usage)

    parser.add_option("-p", "--port",
                      dest="port",
                      default = None,
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
    PORT      = options.port 
    BAUD      = options.baud
    TIMEOUT   = options.timeout
    DEBUG     = options.debug

    # Scan the ports if none given
    if not PORT:
        for port in scanports():
            if 'usbserial' in port:
                PORT = port
                break
        if not PORT:
            print 'Port not found, please connect device or set before running'
            sys.exit()

    if DEBUG:
        print 'PORT %s' % PORT
        print 'BAUD %s' % BAUD
        print 'TIMEOUT %s' % TIMEOUT
        
    # Connect to serial port and wait for arduino reboot and startup
    try:
        ser = serial.Serial(PORT,BAUD,timeout=TIMEOUT)
        time.sleep(10.0)
    except serial.SerialException, e:
        print 'Serial connection could not be established:\n\t',e
        sys.exit()

    password_mgr = urllib2.HTTPPasswordMgrWithDefaultRealm()
    top_level_url = "http://reach-bb.k1k.me/json/full/"
    password_mgr.add_password(None, top_level_url, 'pass', 'word')
    handler = urllib2.HTTPBasicAuthHandler(password_mgr)
    opener = urllib2.build_opener(handler)
    urllib2.install_opener(opener)
    page = urllib2.urlopen(top_level_url + 'waterfall').read()

    while 1:

        # Get the magnitude from the feed
        mag = 5.0
        
        # Pack up the value and send it
        packed = struct.pack('f', mag)
        if DEBUG: print mag, binascii.hexlify(packed)

        try:
            ser.write(packed)

            # Delay before next notification
            time.sleep(mag)
            time.sleep(5)
    
            # Confirm that value was received
            confirm = ser.readline()
            if DEBUG: print confirm

        except Exception, e:
            print e
        
        # Wait 30 seconds for update
        time.sleep(30)

