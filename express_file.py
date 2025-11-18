#!/usr/bin/python
# coding: utf-8

import sys
import base64
import hashlib
import hmac
import logging

import base64
import json
import requests
import os
import datetime
import argparse


bot_id = ''
bot_url = 'https://express.domain.com'
secret = ""
sendto = ""

def parse_args():
    parser = argparse.ArgumentParser(description='Express bot')
    parser.add_argument('--f', type=str, help='parsing file')
    args = parser.parse_args()
    return args


def get_token():
    token_url = '/api/v2/botx/bots/' + bot_id + '/token'
    h = hmac.new(secret.encode('utf-8'), bot_id.encode('utf-8'), hashlib.sha256)
    signature = base64.b16encode(h.digest())
    r = requests.get(bot_url + token_url, params={'signature': signature})
    return r.json()['result']


token = get_token()
if token:
    headers = {
        'authorization': 'Bearer ' + token,
        'content-type': 'application/json'
    }
else:
    logging.info(datetime.datetime.now(), 'Не получен токен', token)


#  /api/v4/botx/notifications/direct
msg_url = '/api/v4/botx/notifications/direct'

'''
def send_text(text):
    all_t = text.split(",")
    send_express(all_t)

def send_text_from_file(text):
    print('error')
'''

def send_express(text):
    lines = []
    with open(text, 'r', encoding="utf-8") as file:
        lines = file.readlines()
        lines = [line.rstrip() for line in lines]
    a = len(lines)
    msg = ''
    i = 0
    while i < int(a):
        c = lines[i]
        msg += str(c) +'\n'
        i += 1
    print(msg)

    data = {
        "group_chat_id": sendto,
        "notification": {
            "status": "ok",
            "body": msg
        },

    }

    try:
        requests.post(bot_url + msg_url, headers=headers, data=json.dumps(data))
    except Exception as ex:
        logging.info(repr(ex))


if __name__ == '__main__':
    args = parse_args()
    if args.f:
        text = args.f
        send_express(text)