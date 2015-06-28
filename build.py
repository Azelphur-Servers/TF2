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
        os.rename(os.path.join(thing, path), os.path.join('build', path))

with open('surf.yaml', 'r') as stream:
    config = yaml.load(stream)


for thing in ['metamod', 'sourcemod']:
    if not os.path.exists(thing+'.tar.gz'):
        subprocess.call(['wget', '-O', thing+'.tar.gz', config[thing]['url']])

    if os.path.exists(thing):
        shutil.rmtree(thing)

    os.mkdir(thing)

    subprocess.call(['tar', 'zxf', thing+'.tar.gz', '-C', thing])

    do_update(thing)

os.mkdir('build/addons/sourcemod/plugins')

for root, dirs, files in os.walk('sourcemod_plugins'):
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
        for root, dirs, files in os.walk(os.path.join(f, 'scripting')):
            for name in files:
                if name[-3:] == '.sp':
                    print 'Building', os.path.join(root, name)
                    spcomp = os.path.abspath('./sourcemod/addons/sourcemod/scripting/spcomp')
                    sp = os.path.abspath(os.path.join(root, name))
                    origWD = os.getcwd()
                    os.chdir('build/addons/sourcemod/plugins/')
                    subprocess.call(
                        [
                            spcomp,
                            sp
                        ],
                    )
                    os.chdir(origWD)

os.mkdir('build/addons/sourcemod/configs')

for cfg in config['sourcemod']['configs']:
    f = os.path.join('sourcemod/addons/sourcemod/configs', cfg)
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
