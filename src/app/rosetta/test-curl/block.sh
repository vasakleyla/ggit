#!/bin/bash

. lib.sh

req /block '{ network_identifier: { blockchain: "mina", network: "debug" }, block_identifier: { index: 2 }, metadata: {} }'

