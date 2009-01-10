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

package com.whirled.contrib.platformer.persist {

import flash.events.Event;
import flash.events.EventDispatcher;

import com.whirled.game.GameControl;

import com.threerings.util.HashMap;

public class PersistenceManager extends EventDispatcher
{
    public function PersistenceManager (gameCtrl :GameControl, properties :Array)
    {
        _trophyProperties = new HashMap();
        var cookieProperties :HashMap = new HashMap();
        for each (var prototype :PropertyPrototype in properties) {
            if (prototype.type == PropertyType.TROPHY) {
                _trophyProperties.put(
                    prototype.name, new TrophyProperty(prototype.name, gameCtrl));

            } else if (prototype.type == PropertyType.COOKIE) {
                cookieProperties.put(prototype.name, prototype.defaultValue);
            }
        }

        _cookieManager = new CookieManager(gameCtrl, cookieProperties);
        _loaded = _cookieManager.loaded;
        if (!_loaded) {
            _cookieManager.addEventListener(Event.COMPLETE, loadingComplete);
        }
    }

    public function get loaded () :Boolean
    {
        return _loaded;
    }

    public function getProperty (name :String) :PersistentProperty
    {
        var trophyProperty :TrophyProperty = _trophyProperties.get(name);
        return trophyProperty != null ? trophyProperty : _cookieManager.getProperty(name);
    }

    protected function loadingComplete (...ignored) :void
    {
        _loaded = true;
        _cookieManager.removeEventListener(Event.COMPLETE, loadingComplete);
        dispatchEvent(new Event(Event.COMPLETE));
    }

    protected var _cookieManager :CookieManager;
    protected var _loaded :Boolean = false;
    protected var _trophyProperties :HashMap;
}
}
