#!/usr/bin/env python
# -*- coding: utf-8 -*-
##
# Tart Mailer
#
# Copyright (c) 2013, Tart İnternet Teknolojileri Ticaret AŞ
#
# Permission to use, copy, modify, and/or distribute this software for any purpose with or without fee is hereby
# granted, provided that the above copyright notice and this permission notice appear in all copies.
#
# The software is provided "as is" and the author disclaims all warranties with regard to the software including all
# implied warranties of merchantability and fitness. In no event shall the author be liable for any special, direct,
# indirect, or consequential damages or any damages whatsoever resulting from loss of use, data or profits, whether
# in an action of contract, negligence or other tortious action, arising out of or in connection with the use or
# performance of this software.
##

import os
import io
import flask

os.sys.path.append(os.path.join(os.path.dirname(os.path.realpath(__file__)), '..'))
from libtart.postgres import Postgres

app = flask.Flask(__name__)
app.config.update(**dict((k[6:], v) for k, v in os.environ.items() if k[:6] == 'FLASK_'))

@app.route('/')
def index():
    '''Index page to check that the web server works.'''
    return ''

@app.route('/trackerImage/<emailHash>')
def trackerImage(emailHash):
    with Postgres() as postgres:
        postgres.call('NewEmailSendFeedback', (emailHash, 'trackerImage', flask.request.remote_addr))

    # Return 1px * 1px transparent image.
    return flask.send_file(io.BytesIO('GIF89a\x01\x00\x01\x00\x80\x00\x00\xff\xff\xff\x00\x00\x00!\xf9\x04\x01\x00\x00\x00\x00,\x00\x00\x00\x00\x01\x00\x01\x00\x00\x02\x02D\x01\x00;'), mimetype='image/gif')

@app.route('/view/<emailHash>')
def view(emailHash):
    with Postgres() as postgres:
        postgres.call('NewEmailSendFeedback', (emailHash, 'view', flask.request.remote_addr))
        body = postgres.call('ViewEmailBody', emailHash)

    if body:
        return body
    flask.abort(404)

@app.route('/redirect/<emailHash>')
def redirect(emailHash):
    with Postgres() as postgres:
        postgres.call('NewEmailSendFeedback', (emailHash, 'redirect', flask.request.remote_addr))
        redirectURL = postgres.call('EmailSendRedirectURL', emailHash)

    if redirectURL:
        return flask.redirect(redirectURL)
    flask.abort(404)

@app.route('/unsubscribe/<emailHash>')
def unsubscribe(emailHash):
    with Postgres() as postgres:
        if postgres.call('NewEmailSendFeedback', (emailHash, 'unsubscribe', flask.request.remote_addr)):
            return 'You are successfully unsubscribed.'
        else:
            return 'You have already unsubscribed.'

if __name__ == '__main__':
    app.run(host='0.0.0.0', port=8000, debug=True)
