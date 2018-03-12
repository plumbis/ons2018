#!/usr/bin/env bash
net add bridge stp off
net commit
sleep 5m
net del bridge stp off
net commit