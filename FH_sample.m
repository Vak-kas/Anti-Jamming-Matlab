clc;
clear;
MHz = 1e6;
GHz = 1e9;

%% 초기 환경 변수
N = 60; %채널 개수
BW_ch = 50 * MHz; %channel bandwidth = 50 MHz


f_start = 26.5 * GHz; %26.5GHz
f_end = 29.5 * GHz; %29.5GHz



%% 실험 환경 구성

% 채널 생성
channels = f_start + (0:N-1) * BW_ch;

