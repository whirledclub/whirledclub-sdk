// Whirled contrib library - tools for developing whirled games
// http://www.whirled.com/code/contrib/asdocs
//
// This library is free software: you can redistribute it and/or modify
// it under the terms of the GNU Lesser General Public License as published by
// the Free Software Foundation, either version 3 of the License, or
// (at your option) any later version.
//
// This library is distributed in the hope that it will be useful,
// but WITHOUT ANY WARRANTY; without even the implied warranty of
// MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
// GNU Lesser General Public License for more details.
//
// You should have received a copy of the GNU Lesser General Public License
// along with this library.  If not, see <http://www.gnu.org/licenses/>.
//
// Copyright 2008 Three Rings Design
//
// $Id$

package com.whirled.contrib.simplegame {

import com.whirled.contrib.simplegame.audio.*;
import com.whirled.contrib.simplegame.resource.*;

import flash.display.Sprite;
import flash.events.IEventDispatcher;

public class SimpleGame
{
    public function SimpleGame (config :Config = null)
    {
        if (config == null) {
            config = new Config();
        }

        _ctx.mainLoop = new MainLoop(_ctx);
        _ctx.audio = new AudioManager(_ctx, config.maxAudioChannels);
        _ctx.mainLoop.addUpdatable(_ctx.audio);

        if (config.externalResourceManager == null) {
            _ctx.rsrcs = new ResourceManager();
            _ownsResourceManager = true;

            // add resource factories
            _ctx.rsrcs.registerResourceType("image", ImageResource);
            _ctx.rsrcs.registerResourceType("swf", SwfResource);
            _ctx.rsrcs.registerResourceType("xml", XmlResource);
            _ctx.rsrcs.registerResourceType("sound", SoundResource);

        } else {
            _ctx.rsrcs = config.externalResourceManager;
            _ownsResourceManager = false;
        }
    }

    public function run (hostSprite :Sprite, keyDispatcher :IEventDispatcher = null) :void
    {
        _ctx.mainLoop.setup();
        _ctx.mainLoop.run(hostSprite, keyDispatcher);
    }

    public function shutdown () :void
    {
        _ctx.mainLoop.shutdown();
        _ctx.audio.shutdown();

        if (_ownsResourceManager) {
            _ctx.rsrcs.shutdown();
        }
    }

    public function get ctx () :SGContext
    {
        return _ctx;
    }

    protected var _ctx :SGContext = new SGContext();
    protected var _ownsResourceManager :Boolean;
}

}
