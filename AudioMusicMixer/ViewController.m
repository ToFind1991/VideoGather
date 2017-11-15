//
//  ViewController.m
//  AudioMusicMixer
//
//  Created by shiwei on 17/11/2.
//  Copyright © 2017年 shiwei. All rights reserved.
//

#import "ViewController.h"
#import "TFMusicListViewController.h"
#import "TFAudioRecorder.h"
#import "TFAudioMixer.h"
#import "TFAudioFileReader.h"
#import "TFAudioFileWriter.h"
#import "TFMediaListViewController.h"
#import "TFAudioUnitPlayer.h"
#import "AUGraphMixer.h"

#define SimultaneousRecordAndMix    1
#define MixPcmData  1

#define TestTwoFileMix  0
#define TestOneFileAndRecordVoice    0
#define TestAUGraphMixer 1      //使用audioUnit graph 实现音频文件和录音混音，再实时播放的需求

@interface ViewController (){
    
    TFMediaData *_selectedMusic;
    TFAudioFileReader *_fileReader;
    
#if TestTwoFileMix
    TFMediaData *_selectedMusic2;
    TFAudioFileReader *_fileReader2;
#endif
    
#if TestOneFileAndRecordVoice
    TFAudioRecorder *_recorder;
#endif
    
#if TestAUGraphMixer
    AUGraphMixer * _AUGraphMixer;
#endif

    TFAudioMixer *_mixer;
    TFAudioFileWriter *_writer;
    
    NSString *_curRecordPath;
    TFAudioUnitPlayer *_audioPlayer;
    
}
@property (weak, nonatomic) IBOutlet UILabel *musicLabel;
@property (weak, nonatomic) IBOutlet UIButton *recordButton;

@property (nonatomic, copy) NSString *recordHome;
@property (weak, nonatomic) IBOutlet UISlider *leftVolumeSlider;
@property (weak, nonatomic) IBOutlet UISlider *rightVolumeSlider;

@end

@implementation ViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    
    
}

-(void)prepareForSegue:(UIStoryboardSegue *)segue sender:(id)sender{
    if ([segue.identifier isEqualToString:@"selectMusic"]) {
        TFMusicListViewController *destVC = segue.destinationViewController;
        destVC.selectMusicConpletionHandler = ^(TFMediaData *music){
            
#if TestOneFileAndRecordVoice || TestAUGraphMixer
            _selectedMusic = music;
            _musicLabel.text = music.filename;
#endif
            
#if TestTwoFileMix
            if (!_selectedMusic) {
                _selectedMusic = music;
                _musicLabel.text = music.filename;
            }else{
                _selectedMusic2 = music;
                _musicLabel.text = music.filename;
            }
#endif
        };
    }
}

-(BOOL)mixRuning{
    
#if TestTwoFileMix
    return _mixer.runing;
#endif
    
#if TestOneFileAndRecordVoice
    return _recorder.recording;
#endif
    
#if TestAUGraphMixer
    return _AUGraphMixer.isRuning;
#endif
}

- (IBAction)recordOrStop:(UIButton *)button {
    
#if TestTwoFileMix
    [self twoFileStartOrStop:button];
#endif
    
#if TestOneFileAndRecordVoice
    [self oneFileStartOrStop:button];
#endif
    
#if TestAUGraphMixer
    [self AUGraphMixerStartOrStop:button];
#endif
    
    if ([self mixRuning]) {
        [button setTitle:@"stop" forState:(UIControlStateNormal)];
    }else{
        [button setTitle:@"run" forState:(UIControlStateNormal)];
    }
}

#if TestOneFileAndRecordVoice
-(void)oneFileStartOrStop:(UIButton *)sender{
    if ([self mixRuning]) {
        [_recorder stop];
        [_writer close];
    }else{
        _mixer = [[TFAudioMixer alloc] init];
        
        _fileReader = [[TFAudioFileReader alloc] init];
        _fileReader.filePath = _selectedMusic.filePath;
        _mixer.pullAudioSource = _fileReader;
        
        _writer = [[TFAudioFileWriter alloc] init];
        _writer.filePath = [self nextRecordPath];
        _writer.fileType = kAudioFileCAFType;
        [_mixer addTarget:_writer];

        _recorder = [[TFAudioRecorder alloc] init];
        [_recorder addTarget:_mixer inputIndex:0];
        [_recorder start];
    }
}

#endif

#if TestTwoFileMix
-(void)twoFileStartOrStop:(UIButton *)sender{
    if ([self mixRuning]) {
        [_mixer stop];
        [_writer close];
    }else{
        
        _mixer = [[TFAudioMixer alloc] init];
        
        _fileReader = [[TFAudioFileReader alloc] init];
        _fileReader.filePath = _selectedMusic.filePath;
        _mixer.pullAudioSource = _fileReader;
        
        _writer = [[TFAudioFileWriter alloc] init];
        _writer.filePath = [self nextRecordPath];
        _writer.fileType = kAudioFileCAFType;
        [_mixer addTarget:_writer];
        
        _fileReader2= [[TFAudioFileReader alloc] init];
        _fileReader2.filePath = _selectedMusic2.filePath;
        _mixer.pullAudioSource2 = _fileReader2;
        
        if (_selectedMusic.duration > _selectedMusic2.duration) {
            _fileReader2.isRepeat = YES;
        }else{
            _fileReader.isRepeat = YES;
        }
        
        _mixer.sourceType = TFAudioMixerSourceTypeTwoPull;
        [_mixer start];
    }
}

#endif

#if TestAUGraphMixer
-(void)AUGraphMixerStartOrStop:(UIButton *)sender{
    if ([self mixRuning]) {
        [_AUGraphMixer stop];
    }else{
        
        _AUGraphMixer = [[AUGraphMixer alloc] init];
        _AUGraphMixer.leftVolume = _leftVolumeSlider.value;
        _AUGraphMixer.rightVolume = _rightVolumeSlider.value;
        [_AUGraphMixer setupAUGraph];
        
        _AUGraphMixer.musicFilePath = _selectedMusic.filePath;
        [_AUGraphMixer start];
    }
}
#endif

-(NSString *)recordHome{
    if (!_recordHome) {
        _recordHome = [NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES).firstObject stringByAppendingPathComponent:@"audioMusicMix"];
        if (![[NSFileManager defaultManager] fileExistsAtPath:_recordHome]) {
            [[NSFileManager defaultManager] createDirectoryAtPath:_recordHome withIntermediateDirectories:YES attributes:nil error:nil];
        }
    }
    
    return _recordHome;
}

-(NSString *)nextRecordPath{
    NSString *name = [NSString stringWithFormat:@"%.0f",[[NSDate date] timeIntervalSince1970]];
    
    _curRecordPath = [self.recordHome stringByAppendingPathComponent:name];
    
    return _curRecordPath;
}

- (IBAction)showMixedList:(id)sender {
    TFMediaListViewController *mediaListVC = [[TFMediaListViewController alloc] init];
    mediaListVC.mediaDir = self.recordHome;
    
    mediaListVC.selectHandler = ^(TFMediaData *mediaData){
        NSLog(@"select audio file %@",mediaData.filename);
        
        //play audio file
        if (mediaData.isAudio) {
            if (!_audioPlayer) {
                _audioPlayer = [[TFAudioUnitPlayer alloc] init];
            }
            NSLog(@"play mixed");
            [_audioPlayer playLocalFile:mediaData.filePath];
        }
    };
    
    mediaListVC.disappearHandler = ^(){
        [_audioPlayer stop];
    };
    
    [self.navigationController pushViewController:mediaListVC animated:YES];
}


- (IBAction)volumeChanged:(UISlider *)slider {
    if (slider == _leftVolumeSlider) {
        _AUGraphMixer.leftVolume = slider.value;
    }else{
        _AUGraphMixer.rightVolume = slider.value;
    }
}


@end
