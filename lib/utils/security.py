#
#

# Copyright (C) 2013 Google Inc.
#
# This program is free software; you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation; either version 2 of the License, or
# (at your option) any later version.
#
# This program is distributed in the hope that it will be useful, but
# WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
# General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program; if not, write to the Free Software
# Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA
# 02110-1301, USA.

"""Utility functions for security features of Ganeti.

"""

import logging


def AddNodeToCandidateCerts(node_uuid, cert_digest, candidate_certs,
                            info_fn=logging.info, warn_fn=logging.warn):
  """Adds an entry to the candidate certificate map.

  @type node_uuid: string
  @param node_uuid: the node's UUID
  @type cert_digest: string
  @param cert_digest: the digest of the node's client SSL certificate
  @type candidate_certs: dict of strings to strings
  @param candidate_certs: map of node UUIDs to the digests of their client
      SSL certificates, will be manipulated in this function
  @type info_fn: function
  @param info_fn: logging function for information messages
  @type warn_fn: function
  @param warn_fn: logging function for warning messages

  """
  assert candidate_certs is not None

  if node_uuid in candidate_certs:
    old_cert_digest = candidate_certs[node_uuid]
    if old_cert_digest == cert_digest:
      info_fn("Certificate digest for node %s already in config."
              "Not doing anything." % node_uuid)
      return
    else:
      warn_fn("Overriding differing certificate digest for node %s"
              % node_uuid)
  candidate_certs[node_uuid] = cert_digest


def RemoveNodeFromCandidateCerts(node_uuid, candidate_certs,
                                 warn_fn=logging.warn):
  """Removes the entry of the given node in the certificate map.

  @type node_uuid: string
  @param node_uuid: the node's UUID
  @type candidate_certs: dict of strings to strings
  @param candidate_certs: map of node UUIDs to the digests of their client
      SSL certificates, will be manipulated in this function
  @type warn_fn: function
  @param warn_fn: logging function for warning messages

  """
  if node_uuid not in candidate_certs:
    warn_fn("Cannot remove certifcate for node %s, because it's not in the"
            "candidate map." % node_uuid)
    return
  del candidate_certs[node_uuid]