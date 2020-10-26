#!/bin/bash

sourcefile=$1
destfile=$2

# Overly simple validation
if [ ! -e "$sourcefile" ]; then
  echo 'Please provide an existing input file.'
  exit
fi

if [ "$destfile" == "" ]; then
  echo 'Please provide an output preview file name (without extension).'
  exit
fi

# Destination file extension
extension="webm"

# Get video length in seconds
length=$(ffprobe $sourcefile  -show_format 2>&1 | sed -n 's/duration=//p' | awk '{print int($0)}')

# Start 6 seconds into the video to avoid opening credits (arbitrary)
starttimeseconds=6

# Mini-snippets will be 2 seconds in length
snippetlengthinseconds=2

# We'll aim for 5 snippets spread throughout the video
desiredsnippets=5

# Ensure the video is long enough to even bother previewing
minlength=$(($snippetlengthinseconds*$desiredsnippets))

# Video dimensions (these could probably be command line arguments)
dimensions=320:-1

# Temporary directory and text file where we'll store snippets
# These will be cleaned up and removed when the preview image is generated
tempdir=snippets
listfile=list.txt

# Display and check video length
echo 'Video length: ' $length
if [ "$length" -lt "$minlength" ]
then
  echo 'Video is too short.  Exiting.'
  exit
fi

rm -rf $tempdir $listfile

# Loop and generate video snippets
mkdir $tempdir
interval=$(($length/$desiredsnippets-$starttimeseconds))
for i in $(seq 1 $desiredsnippets)
  do
    # Format the second marks into hh:mm:ss format
    start=$(($(($i*$interval))+$starttimeseconds))
    formattedstart=$(printf "%02d:%02d:%02d\n" $(($start/3600)) $(($start%3600/60)) $(($start%60)))
    echo 'Generating preview part ' $i $formattedstart
    # Generate the snippet at calculated time
    ffmpeg -i $sourcefile -vf scale=$dimensions -c:v libvpx-vp9 -b:v 285K -crf 28 -threads 8 -speed 2 -tile-columns 6 -frame-parallel 1 -auto-alt-ref 1 -lag-in-frames 25 -c:a libopus -an -ss $formattedstart -t $snippetlengthinseconds $tempdir/$i.$extension &>/dev/null
done

# Concat videos
echo 'Generating final preview file'

# Generate a text file with one snippet video location per line
# (https://trac.ffmpeg.org/wiki/Concatenate)
for f in $tempdir/*; do echo "file '$f'" >> $listfile; done

rm -rf $destfile.$extension

# Concatenate the files based on the generated list
ffmpeg -f concat -safe 0 -i $listfile -c copy $destfile.$extension &>/dev/null

echo 'Done!  Check ' $destfile.$extension '!'

# Cleanup
rm -rf $tempdir $listfile
