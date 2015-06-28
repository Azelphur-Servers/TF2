import yaml
import urllib
import urlparse
import subprocess
import os
import shutil


def mkdir(path):
    folder = os.path.dirname(path)
    if not os.path.exists(folder):
        os.makedirs(folder)


def do_update(thing):
    for path in config[thing]['update']:
        mkdir(os.path.abspath(os.path.join('build', path)))
        os.rename(os.path.join('extract', path), os.path.join('build', path))

with open('surf.yaml', 'r') as stream:
    config = yaml.load(stream)


for thing in ['metamod', 'sourcemod']:
    if not os.path.exists(thing+'.tar.gz'):
        subprocess.call(['wget', '-O', thing+'.tar.gz', config[thing]['url']])

    if os.path.exists('extract'):
        shutil.rmtree('extract')

    os.mkdir('extract')

    subprocess.call(['tar', 'zxf', thing+'.tar.gz', '-C', 'extract'])

    do_update(thing)

os.mkdir('build/addons/sourcemod/plugins')

for plugin in config['sourcemod']['plugins']:
    f = os.path.join('extract/addons/sourcemod/plugins', plugin+'.smx')
    if os.path.exists(f):
        os.rename(f, 'build/addons/sourcemod/plugins/'+plugin+'.smx')

    f = os.path.join('extract/addons/sourcemod/plugins/disabled', plugin+'.smx')
    if os.path.exists(f):
        os.rename(f, 'build/addons/sourcemod/plugins/'+plugin+'.smx')

os.mkdir('build/addons/sourcemod/configs')

for cfg in config['sourcemod']['configs']:
    f = os.path.join('extract/addons/sourcemod/configs', cfg)
    if os.path.exists(f):
        os.rename(f, os.path.join('build/addons/sourcemod/configs/', cfg))

os.mkdir('build/cfg')

for cfg in config['configs']:
    f = os.path.join('cfg', cfg)
    if os.path.exists(f):
        if os.path.isdir(f):
            shutil.copytree(f, os.path.join('build/cfg/', cfg))
        else:
            shutil.copy(f, os.path.join('build/cfg/', cfg))
