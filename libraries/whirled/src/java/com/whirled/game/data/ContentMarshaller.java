//
// $Id$
//
// Copyright (c) 2007-2009 Three Rings Design, Inc. Please do not redistribute.

package com.whirled.game.data;

import com.threerings.presents.client.Client;
import com.threerings.presents.client.InvocationService;
import com.threerings.presents.data.InvocationMarshaller;
import com.whirled.game.client.ContentService;

/**
 * Provides the implementation of the {@link ContentService} interface
 * that marshalls the arguments and delivers the request to the provider
 * on the server. Also provides an implementation of the response listener
 * interfaces that marshall the response arguments and deliver them back
 * to the requesting client.
 */
public class ContentMarshaller extends InvocationMarshaller
    implements ContentService
{
    /** The method id used to dispatch {@link #consumeItemPack} requests. */
    public static final int CONSUME_ITEM_PACK = 1;

    // from interface ContentService
    public void consumeItemPack (Client arg1, String arg2, InvocationService.InvocationListener arg3)
    {
        ListenerMarshaller listener3 = new ListenerMarshaller();
        listener3.listener = arg3;
        sendRequest(arg1, CONSUME_ITEM_PACK, new Object[] {
            arg2, listener3
        });
    }
}
