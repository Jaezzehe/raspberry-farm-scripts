#!/bin/bash
source /opt/miniconda/etc/profile.d/conda.sh
conda activate /opt/miniconda/envs/statsenv
exec python /opt/raspberry-farm-scripts/stats.py