#!/usr/bin/env bash
net add bridge stp off
net commit
sleep 45
net del bridge stp off
net commit