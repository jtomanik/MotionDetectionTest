#  Motion Detection Test

This is a simple and quite shitty program for testing motion detection using Vision framework. 


### Video Processing Pipeline
The main work is done inside video processing pipeline that consists of following sections

#### Frame Sources
Those can be: Live camera feed or playback of pre-recorded file

#### Pre Processing
preprocessing applies bunch of CIFilters in order to (ideally) improve video analysis

#### Video Analysis
This step calculates optical flow between two frames on a per-pixel basis

#### Video Visualiser
If we have frames containing optical flow then we need to visualise it and convert it back to pixels

