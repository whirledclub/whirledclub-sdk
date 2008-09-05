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

package com.whirled.contrib.platformer.editor {

import flash.display.Shape;
import flash.display.Sprite;

import flash.events.Event;
import flash.events.KeyboardEvent;
import flash.events.MouseEvent;

import flash.geom.Point;

import com.threerings.util.KeyboardCodes;

import com.threerings.flash.MathUtil;

import com.whirled.contrib.platformer.board.Board;
import com.whirled.contrib.platformer.display.Layer;
import com.whirled.contrib.platformer.display.Metrics;
import com.whirled.contrib.platformer.piece.Piece;

public class EditSprite extends Sprite
{
    public function EditSprite ()
    {
        addEventListener(MouseEvent.MOUSE_DOWN, mouseDownHandler);
        addEventListener(MouseEvent.MOUSE_UP, mouseUpHandler);
        addEventListener(MouseEvent.MOUSE_OUT, mouseOutHandler);
        addEventListener(MouseEvent.MOUSE_OVER, mouseOverHandler);
        addEventListener(MouseEvent.MOUSE_MOVE, mouseMoveHandler);
        addEventListener(MouseEvent.CLICK, onClick);
        addEventListener(Event.ADDED_TO_STAGE, onAddedToStage);

        focusRect = false;
    }

    public function positionView (nX :Number, nY :Number) :void
    {
        _bX = nX;
        _bY = nY;
        updateDisplay();
    }

    public function moveView (dX :Number, dY :Number) :void
    {
        _bX += dX;
        _bY += dY;
        updateDisplay();
    }

    public function getX () :int
    {
        return _bX / Metrics.TILE_SIZE;
    }

    public function getY () :int
    {
        return -_bY / Metrics.TILE_SIZE;
    }

    public function moveViewTile (dX :int, dY :int) :void
    {
        //trace("moveViewTile (" + dX + ", " + dY + ")");
        moveView(dX * Metrics.TILE_SIZE, dY * Metrics.TILE_SIZE);
    }

    public function positionViewTile (dX :int, dY :int) :void
    {
        positionView(dX * Metrics.TILE_SIZE, dY * Metrics.TILE_SIZE);
    }

    public function getMouseX () :int
    {
        return Math.floor((_bX + mouseX * _scale) / Metrics.TILE_SIZE);
    }

    public function getMouseY () :int
    {
        return Math.floor(((Metrics.DISPLAY_HEIGHT - mouseY) * _scale - _bY) / Metrics.TILE_SIZE);
    }

    public function setScale (scale :int) :void
    {
        scale = MathUtil.clamp(scale, -2, 8);
        if (scale < 0) {
            _scale = 1 / -(scale - 1);
        } else {
            _scale = scale + 1;
        }
        updateDisplay();
    }

    public function toggleGrid () :void
    {
        _layers[GRID_LAYER].alpha = _layers[GRID_LAYER].alpha > 0 ? 0 : 0.5;
        updateDisplay();
    }

    protected function get GRID_LAYER () :int
    {
        return 0;
    }

    protected function clearDisplay () :void
    {
    }

    protected function initDisplay () :void
    {
        addChildAt(_layers[GRID_LAYER] = new GridLayer(), GRID_LAYER);
        _layers[GRID_LAYER].alpha = 0.5;

        var masker :Shape = new Shape();
        masker.graphics.beginFill(0x000000);
        masker.graphics.drawRect(0, 0, Metrics.DISPLAY_WIDTH, Metrics.DISPLAY_HEIGHT);
        masker.graphics.endFill();
        mask = masker;
        addChildAt(masker, 0);
        masker = new Shape();
        masker.graphics.beginFill(0xEEEEEE);
        masker.graphics.drawRect(0, 0, Metrics.DISPLAY_WIDTH, Metrics.DISPLAY_HEIGHT);
        masker.graphics.endFill();
        addChildAt(masker, 0);

        positionView(0, 0);
    }

    protected function updateDisplay () :void
    {
        for each (var layer :Layer in _layers) {
            if (layer != null) {
                layer.update(_bX / _scale, _bY / _scale, _scale);
            }
        }
    }

    protected function mouseDownHandler (event :MouseEvent) :void
    {
    }

    protected function mouseUpHandler (event :MouseEvent) :void
    {
        clearDrag();
    }

    protected function mouseOverHandler (event :MouseEvent) :void
    {
        if (!event.buttonDown) {
            clearDrag();
        }
    }

    protected function mouseOutHandler (event: MouseEvent) :void
    {
    }

    protected function mouseMoveHandler (event :MouseEvent) :void
    {
        var newX :int = getMouseX();
        var newY :int = getMouseY();
        if (newX != _mX || newY != _mY) {
            tileChanged(newX, newY);
            _mX = newX;
            _mY = newY;
        }
    }

    protected function tileChanged (newX :int, newY :int) :void
    {
    }

    protected function clearDrag () :void
    {
    }

    protected function onClick (event :MouseEvent) :void
    {
        stage.focus = this;
    }

    protected function onAddedToStage (event :Event) :void
    {
        addEventListener(KeyboardEvent.KEY_DOWN, keyPressed);
    }

    protected function keyPressed (event :KeyboardEvent) :void
    {
        if (event.keyCode == KeyboardCodes.RIGHT) {
            moveViewTile(1 * _scale, 0);
        } else if (event.keyCode == KeyboardCodes.DOWN) {
            moveViewTile(0, 1 * _scale);
        } else if (event.keyCode == KeyboardCodes.LEFT) {
            moveViewTile(-1 * _scale, 0);
        } else if (event.keyCode == KeyboardCodes.UP) {
            moveViewTile(0, -1 * _scale);
        }
    }

    /** The board layers. */
    protected var _layers :Array = new Array();

    protected var _bX :int;
    protected var _bY :int;

    protected var _mX :int;
    protected var _mY :int;

    protected var _scale :Number = 2;
}
}
