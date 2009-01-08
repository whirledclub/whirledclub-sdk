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

package com.whirled.contrib.platformer.board {

import com.whirled.contrib.platformer.util.Maths;

import com.whirled.contrib.platformer.game.ActorController;

import com.whirled.contrib.platformer.piece.Actor;
import com.whirled.contrib.platformer.piece.Dynamic;

public class FlyTask extends ColliderTask
{
    public function FlyTask (
            ac :ActorController, col :Collider, maxDx :Number = 3, maxDy :Number = 1)
    {
        super(ac, col);
        _sab = col.getDynamicBounds(ac.getActor()) as SimpleActorBounds;
        _maxDx = maxDx;
        _maxDy = maxDy;
    }

    override public function init (delta :Number) :void
    {
        super.init(delta);
        _lastDelta = NaN;
        _hitX = false;
        _hitY = false;
    }

    override public function getBounds () :DynamicBounds
    {
        return _sab;
    }

    override public function genCD (ct :ColliderTask = null) :ColliderDetails
    {
        if (_cd == null) {
            updateVector();
        } else if (ct != null) {
            _sab.updatedDB(_cd, ct.getBounds());
        }
        _cd = _sab.findColliders(_delta, _cd);
        return _cd;
    }

    public function didHitX () :Boolean
    {
        return _hitX;
    }

    public function didHitY () :Boolean
    {
        return _hitY;
    }

    protected function updateVector () :void
    {
        var a :Actor = _sab.actor;
        a.dy += a.accelY * _delta;
        a.dy -= Maths.sign0(a.dy) * Maths.limit(DRAG * _delta, Math.abs(a.dy));
        var maxDy :Number = (a.health > 0) ? _maxDy : MAX_DEAD_DY;
        a.dy = Math.min(Math.max(a.dy, -maxDy), maxDy);
        a.dx += a.accelX * _delta;
        a.dx -= Maths.sign0(a.dx) * Maths.limit(DRAG * _delta, Math.abs(a.dx));
        a.dx = Maths.limit(a.dx, _maxDx);
    }

    override protected function runTask () :void
    {
        var a :Actor = _sab.actor;
        _hitX = _hitX || a.dx != 0;
        _hitY = _hitY || a.dy != 0;
        _sab.move(_cd);
        _hitX = _hitX && a.dx == 0;
        _hitY = _hitY && a.dy == 0;
        if (_cd != null) {
            if (!isNaN(_lastDelta)) {
                if (_lastDelta == _cd.rdelta) {
                    _cd.rdelta = 0;
                }
            }
            if ((_cd.colliders != null && _cd.colliders.length > 0) ||
                    (_sab.actor.inter == Dynamic.DEAD && (_hitX || _hitY))) {
                _sab.actor.events.push("hit_ground");
            }
            _lastDelta = _delta;
            _delta = _cd.rdelta;
            _cd = null;
        } else {
            _delta = 0;
        }
    }

    protected var _lastDelta :Number;
    protected var _sab :SimpleActorBounds;
    protected var _maxDx :Number;
    protected var _maxDy :Number;
    protected var _hitX :Boolean;
    protected var _hitY :Boolean;

    protected var MAX_DEAD_DY :Number = 6;
    protected var DRAG :Number = 0.5;
}
}
