//
// $Id$
//
// Copyright (c) 2007-2009 Three Rings Design, Inc. Please do not redistribute.

package com.whirled.game.data {

import com.threerings.presents.client.Client;
import com.threerings.presents.client.InvocationService_InvocationListener;
import com.threerings.presents.data.InvocationMarshaller;
import com.threerings.presents.data.InvocationMarshaller_ListenerMarshaller;
import com.whirled.game.client.ContentService;

/**
 * Provides the implementation of the <code>ContentService</code> interface
 * that marshalls the arguments and delivers the request to the provider
 * on the server. Also provides an implementation of the response listener
 * interfaces that marshall the response arguments and deliver them back
 * to the requesting client.
 */
public class ContentMarshaller extends InvocationMarshaller
    implements ContentService
{
    /** The method id used to dispatch <code>consumeItemPack</code> requests. */
    public static const CONSUME_ITEM_PACK :int = 1;

    // from interface ContentService
    public function consumeItemPack (arg1 :Client, arg2 :String, arg3 :InvocationService_InvocationListener) :void
    {
        var listener3 :InvocationMarshaller_ListenerMarshaller = new InvocationMarshaller_ListenerMarshaller();
        listener3.listener = arg3;
        sendRequest(arg1, CONSUME_ITEM_PACK, [
            arg2, listener3
        ]);
    }
}
}
