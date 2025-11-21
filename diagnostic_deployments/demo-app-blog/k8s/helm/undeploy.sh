#!/bin/bash
helm uninstall blog-app-helm -n h-demo-blog && kubectl delete namespace h-demo-blog
