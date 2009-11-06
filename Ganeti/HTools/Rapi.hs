{-| Implementation of the RAPI client interface.

-}

{-

Copyright (C) 2009 Google Inc.

This program is free software; you can redistribute it and/or modify
it under the terms of the GNU General Public License as published by
the Free Software Foundation; either version 2 of the License, or
(at your option) any later version.

This program is distributed in the hope that it will be useful, but
WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
General Public License for more details.

You should have received a copy of the GNU General Public License
along with this program; if not, write to the Free Software
Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA
02110-1301, USA.

-}

module Ganeti.HTools.Rapi
    (
      loadData
    ) where

import Network.Curl
import Network.Curl.Types ()
import Network.Curl.Code
import Data.List
import Control.Monad
import Text.JSON (JSObject, JSValue, fromJSObject)
import Text.Printf (printf)

import Ganeti.HTools.Utils
import Ganeti.HTools.Loader
import Ganeti.HTools.Types
import qualified Ganeti.HTools.Node as Node
import qualified Ganeti.HTools.Instance as Instance

-- | Read an URL via curl and return the body if successful.
getUrl :: (Monad m) => String -> IO (m String)
getUrl url = do
  (code, body) <- curlGetString url [CurlSSLVerifyPeer False,
                                     CurlSSLVerifyHost 0,
                                     CurlTimeout (fromIntegral queryTimeout),
                                     CurlConnectTimeout
                                     (fromIntegral connTimeout)]
  return (case code of
            CurlOK -> return body
            _ -> fail $ printf "Curl error for '%s', error %s"
                 url (show code))

-- | Append the default port if not passed in.
formatHost :: String -> String
formatHost master =
    if elem ':' master then  master
    else "https://" ++ master ++ ":5080"

-- | Parse a instance list in JSON format.
getInstances :: NameAssoc
             -> String
             -> Result [(String, Instance.Instance)]
getInstances ktn body =
    loadJSArray body >>= mapM (parseInstance ktn . fromJSObject)

-- | Parse a node list in JSON format.
getNodes :: String -> Result [(String, Node.Node)]
getNodes body = loadJSArray body >>= mapM (parseNode . fromJSObject)

-- | Construct an instance from a JSON object.
parseInstance :: [(String, Ndx)]
              -> [(String, JSValue)]
              -> Result (String, Instance.Instance)
parseInstance ktn a = do
  name <- fromObj "name" a
  disk <- fromObj "disk_usage" a
  mem <- fromObj "beparams" a >>= fromObj "memory" . fromJSObject
  vcpus <- fromObj "beparams" a >>= fromObj "vcpus" . fromJSObject
  pnode <- fromObj "pnode" a >>= lookupNode ktn name
  snodes <- fromObj "snodes" a
  snode <- (if null snodes then return Node.noSecondary
            else readEitherString (head snodes) >>= lookupNode ktn name)
  running <- fromObj "status" a
  let inst = Instance.create name mem disk vcpus running pnode snode
  return (name, inst)

-- | Construct a node from a JSON object.
parseNode :: [(String, JSValue)] -> Result (String, Node.Node)
parseNode a = do
  name <- fromObj "name" a
  offline <- fromObj "offline" a
  node <- (if offline
           then return $ Node.create name 0 0 0 0 0 0 True
           else do
             drained <- fromObj "drained" a
             mtotal  <- fromObj "mtotal"  a
             mnode   <- fromObj "mnode"   a
             mfree   <- fromObj "mfree"   a
             dtotal  <- fromObj "dtotal"  a
             dfree   <- fromObj "dfree"   a
             ctotal  <- fromObj "ctotal"  a
             return $ Node.create name mtotal mnode mfree
                    dtotal dfree ctotal (offline || drained))
  return (name, node)

-- | Builds the cluster data from an URL.
loadData :: String -- ^ Cluster or URL to use as source
         -> IO (Result (Node.AssocList, Instance.AssocList))
loadData master = do -- IO monad
  let url = formatHost master
  node_body <- getUrl $ printf "%s/2/nodes?bulk=1" url
  inst_body <- getUrl $ printf "%s/2/instances?bulk=1" url
  return $ do -- Result monad
    node_data <- node_body >>= getNodes
    let (node_names, node_idx) = assignIndices node_data
    inst_data <- inst_body >>= getInstances node_names
    let (_, inst_idx) = assignIndices inst_data
    return (node_idx, inst_idx)
