#!/usr/bin/python2

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


def do_include(thing):
    for path in config[thing]['include']:
        mkdir(os.path.abspath(os.path.join('build', path)))
        os.rename(os.path.join(thing, path), os.path.join('build', path))

def sourcemod_build(f):
    print 'Building', f
    spcomp = os.path.abspath('./sourcemod/addons/sourcemod/scripting/spcomp')
    sp = os.path.abspath(f)
    origWD = os.getcwd()
    os.chdir('build/addons/sourcemod/plugins/')
    r = subprocess.call(
        [
            spcomp,
            sp
        ],
    )
    if r:
        print 'Failed to compile, aborting'
        exit()
    os.chdir(origWD)

with open('surf.yaml', 'r') as stream:
    config = yaml.load(stream)


for thing in ['metamod', 'sourcemod']:
    if not os.path.exists(thing+'.tar.gz'):
        subprocess.call(['wget', '-O', thing+'.tar.gz', config[thing]['url']])

    if os.path.exists(thing):
        shutil.rmtree(thing)

    os.mkdir(thing)

    subprocess.call(['tar', 'zxf', thing+'.tar.gz', '-C', thing])

    do_include(thing)

os.mkdir('build/addons/sourcemod/plugins')

for root, dirs, files in os.walk('sourcemod_plugins'):
    for name in files:
        if name[-4:] == '.inc':
            shutil.copy(
                os.path.join(root, name),
                'sourcemod/addons/sourcemod/scripting/include'
            )

for root, dirs, files in os.walk('sourcemod_extensions'):
    for name in files:
        if name[-4:] == '.inc':
            shutil.copy(
                os.path.join(root, name),
                'sourcemod/addons/sourcemod/scripting/include'
            )

for plugin in config['sourcemod']['plugins']:
    f = os.path.join('sourcemod/addons/sourcemod/plugins', plugin+'.smx')
    if os.path.exists(f):
        os.rename(f, 'build/addons/sourcemod/plugins/'+plugin+'.smx')

    f = os.path.join('sourcemod/addons/sourcemod/plugins/disabled', plugin+'.smx')
    if os.path.exists(f):
        os.rename(f, 'build/addons/sourcemod/plugins/'+plugin+'.smx')

    f = os.path.join('sourcemod_plugins/', plugin)
    if os.path.exists(f) and os.path.isdir(f):
        for folder in ['extensions', 'translations', 'gamedata', 'configs']:
            if os.path.exists(os.path.join(f, folder)):
                for t in os.listdir(os.path.join(f, folder)):
                    shutil.copy(
                        os.path.join(f, folder, t),
                        os.path.join('build/addons/sourcemod/', folder, t)
                    )
        for root, dirs, files in os.walk(os.path.join(f, 'scripting')):
            for name in files:
                if name[-3:] == '.sp':
                    sourcemod_build(os.path.join(root, name))

    if os.path.exists(f+'.sp') and os.path.isfile(f+'.sp'):
        sourcemod_build(f+'.sp')

for extension in config['sourcemod']['extensions']:
    f = os.path.join('sourcemod_extensions/', extension)
    if os.path.exists(f) and os.path.isdir(f):
        for folder in ['extensions', 'translations', 'gamedata', 'configs']:
            if os.path.exists(os.path.join(f, folder)):
                for t in os.listdir(os.path.join(f, folder)):
                    shutil.copy(
                        os.path.join(f, folder, t),
                        os.path.join('build/addons/sourcemod/', folder, t)
                    )

for src, dst in config['sourcemod']['configs']:
    f = os.path.join('sourcemod_configs', src)
    if os.path.exists(f):
        shutil.copy(f, os.path.join('build/addons/sourcemod/configs/', dst))
        continue

    f = os.path.join('sourcemod/addons/sourcemod/configs', src)
    if os.path.exists(f):
        os.rename(f, os.path.join('build/addons/sourcemod/configs/', dst))


os.mkdir('build/cfg')

for src, dst in config['configs']:
    f = os.path.join('cfg', src)
    if os.path.exists(f):
        mkdir(os.path.join('build/cfg/', dst))
        if os.path.isdir(f):
            shutil.copytree(f, os.path.join('build/cfg/', dst))
        else:
            shutil.copy(f, os.path.join('build/cfg/', dst))
