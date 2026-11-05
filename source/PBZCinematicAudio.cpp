// Local Media Foundation audio + waveOut. No Lua/Unreal internals or network.
// The only shell action is a user-requested Explorer open of a validated folder.
#define WIN32_LEAN_AND_MEAN
#include <windows.h>
#include <mmsystem.h>
#include <mfapi.h>
#include <mfidl.h>
#include <mfreadwrite.h>
#include <mferror.h>
#include <wrl/client.h>
#include <shellapi.h>
#include <strsafe.h>
#include <vector>
#include <string>
#include <memory>
using Microsoft::WRL::ComPtr;
static HMODULE module;
static SRWLOCK lock=SRWLOCK_INIT;
static volatile LONG generation;
static HWAVEOUT output;
static WAVEHDR header;
static std::vector<BYTE> pcm;
static bool prepared;
static std::wstring root;
static std::wstring moduleRoot(){
 wchar_t p[32768];DWORD n=GetModuleFileNameW(module,p,32768);
 if(!n||n>=32767)return L"";
 std::wstring s(p);for(int i=0;i<2;i++){auto at=s.find_last_of(L"\\/");if(at==s.npos)return L"";s.resize(at);}return s;
}
static void status(const wchar_t* name,const char* state,DWORD code){
 std::wstring p=root+L"\\State\\"+name;char text[96];DWORD wrote;
 StringCchPrintfA(text,96,"%s %lu\n",state,code);
 HANDLE f=CreateFileW(p.c_str(),GENERIC_WRITE,FILE_SHARE_READ,nullptr,CREATE_ALWAYS,FILE_ATTRIBUTE_NORMAL,nullptr);
 if(f!=INVALID_HANDLE_VALUE){WriteFile(f,text,(DWORD)lstrlenA(text),&wrote,nullptr);CloseHandle(f);}
}
static void releaseAudio(){
 if(output){waveOutReset(output);waveOutUnprepareHeader(output,&header,sizeof(header));waveOutClose(output);output=nullptr;}
 ZeroMemory(&header,sizeof(header));pcm.clear();prepared=false;
}
static HRESULT request(const wchar_t* name,std::wstring& path,bool directory){
 HANDLE f=CreateFileW((root+L"\\State\\"+name).c_str(),GENERIC_READ,FILE_SHARE_READ,nullptr,OPEN_EXISTING,FILE_ATTRIBUTE_NORMAL,nullptr);
 if(f==INVALID_HANDLE_VALUE)return HRESULT_FROM_WIN32(GetLastError());
 DWORD size=GetFileSize(f,nullptr),n=0;
 if(!size||size>100000){CloseHandle(f);return E_INVALIDARG;}
 std::string text(size,'\0');BOOL ok=ReadFile(f,text.data(),size,&n,nullptr);CloseHandle(f);
 if(!ok||n!=size)return E_FAIL;
 while(!text.empty()&&(text.back()=='\n'||text.back()=='\r'))text.pop_back();
 if(text.find('\0')!=text.npos||text.find('\n')!=text.npos||text.find('\r')!=text.npos)return E_INVALIDARG;
 int count=MultiByteToWideChar(CP_UTF8,MB_ERR_INVALID_CHARS,text.data(),(int)text.size(),nullptr,0);
 if(count<=0)return E_INVALIDARG;
 std::wstring wide(count,L'\0');MultiByteToWideChar(CP_UTF8,MB_ERR_INVALID_CHARS,text.data(),(int)text.size(),wide.data(),count);
 // Local drive only: URLs, devices and network sources are never handed to MF/Shell.
 if(wide.size()<3||wide[1]!=L':'||(wide[2]!=L'/'&&wide[2]!=L'\\')||!((wide[0]>=L'A'&&wide[0]<=L'Z')||(wide[0]>=L'a'&&wide[0]<=L'z')))return E_INVALIDARG;
 wchar_t full[32768];DWORD length=GetFullPathNameW(wide.c_str(),32768,full,nullptr);
 if(!length||length>=32768)return E_INVALIDARG;path=full;
 DWORD attr=GetFileAttributesW(path.c_str());if(attr==INVALID_FILE_ATTRIBUTES)return HRESULT_FROM_WIN32(GetLastError());
 if(((attr&FILE_ATTRIBUTE_DIRECTORY)!=0)!=directory)return E_INVALIDARG;
 if(!directory){WIN32_FILE_ATTRIBUTE_DATA info;if(!GetFileAttributesExW(path.c_str(),GetFileExInfoStandard,&info))return E_FAIL;
  if(info.nFileSizeHigh||info.nFileSizeLow>512u*1024*1024)return E_INVALIDARG;}
 return S_OK;
}
struct Job{LONG token;std::wstring path;};
static HRESULT decode(Job& job,std::vector<BYTE>& bytes,std::vector<BYTE>& format){
 ComPtr<IMFSourceReader> reader;HRESULT hr=MFCreateSourceReaderFromURL(job.path.c_str(),nullptr,&reader);if(FAILED(hr))return hr;
 PROPVARIANT duration;PropVariantInit(&duration);
 if(SUCCEEDED(reader->GetPresentationAttribute(MF_SOURCE_READER_MEDIASOURCE,MF_PD_DURATION,&duration))&&duration.vt==VT_UI8&&duration.uhVal.QuadPart>600000000ULL){PropVariantClear(&duration);return E_INVALIDARG;}
 PropVariantClear(&duration);
 hr=reader->SetStreamSelection(MF_SOURCE_READER_ALL_STREAMS,FALSE);if(FAILED(hr))return hr;
 hr=reader->SetStreamSelection(MF_SOURCE_READER_FIRST_AUDIO_STREAM,TRUE);
 if(hr==MF_E_INVALIDSTREAMNUMBER)return S_FALSE; // A silent video is valid.
 if(FAILED(hr))return hr;
 ComPtr<IMFMediaType> desired;hr=MFCreateMediaType(&desired);if(FAILED(hr))return hr;
 desired->SetGUID(MF_MT_MAJOR_TYPE,MFMediaType_Audio);desired->SetGUID(MF_MT_SUBTYPE,MFAudioFormat_PCM);desired->SetUINT32(MF_MT_AUDIO_BITS_PER_SAMPLE,16);
 hr=reader->SetCurrentMediaType(MF_SOURCE_READER_FIRST_AUDIO_STREAM,nullptr,desired.Get());if(FAILED(hr))return hr;
 ComPtr<IMFMediaType> actual;hr=reader->GetCurrentMediaType(MF_SOURCE_READER_FIRST_AUDIO_STREAM,&actual);if(FAILED(hr))return hr;
 WAVEFORMATEX* wave=nullptr;UINT32 size=0;hr=MFCreateWaveFormatExFromMFMediaType(actual.Get(),&wave,&size);if(FAILED(hr))return hr;
 if(wave->nChannels<1||wave->nChannels>2||wave->nSamplesPerSec<8000||wave->nSamplesPerSec>96000||wave->wBitsPerSample!=16){CoTaskMemFree(wave);return E_INVALIDARG;}
 format.assign((BYTE*)wave,(BYTE*)wave+size);DWORD maxBytes=wave->nAvgBytesPerSec*60;CoTaskMemFree(wave);
 ULONGLONG began=GetTickCount64();
 for(unsigned i=0;i<100000;i++){
  if(job.token!=InterlockedCompareExchange(&generation,0,0))return HRESULT_FROM_WIN32(ERROR_CANCELLED);
  if(GetTickCount64()-began>15000)return HRESULT_FROM_WIN32(ERROR_TIMEOUT);
  DWORD flags=0;ComPtr<IMFSample> sample;
  hr=reader->ReadSample(MF_SOURCE_READER_FIRST_AUDIO_STREAM,0,nullptr,&flags,nullptr,&sample);if(FAILED(hr))return hr;
  if(flags&MF_SOURCE_READERF_CURRENTMEDIATYPECHANGED)return MF_E_INVALIDMEDIATYPE;
  if(sample){ComPtr<IMFMediaBuffer> data;hr=sample->ConvertToContiguousBuffer(&data);if(FAILED(hr))return hr;
   BYTE* p=nullptr;DWORD length=0;hr=data->Lock(&p,nullptr,&length);if(FAILED(hr))return hr;
   if(bytes.size()+length>maxBytes){data->Unlock();return E_INVALIDARG;}
   bytes.insert(bytes.end(),p,p+length);data->Unlock();}
  if(flags&MF_SOURCE_READERF_ENDOFSTREAM)return bytes.empty()?E_FAIL:S_OK;
 }
 return E_FAIL;
}
static DWORD WINAPI worker(void* raw){
 std::unique_ptr<Job> job((Job*)raw);std::vector<BYTE> data,format;
 HRESULT com=CoInitializeEx(nullptr,COINIT_MULTITHREADED),mf=E_FAIL,hr=com;
 try{if(SUCCEEDED(com)){mf=MFStartup(MF_VERSION);hr=SUCCEEDED(mf)?decode(*job,data,format):mf;}}
 catch(...){hr=E_OUTOFMEMORY;}
 AcquireSRWLockExclusive(&lock);
 if(job->token==InterlockedCompareExchange(&generation,0,0)){
  releaseAudio();DWORD error=FAILED(hr)?(DWORD)hr:0;
  if(!error&&hr!=S_FALSE){pcm.swap(data);auto* wave=(WAVEFORMATEX*)format.data();
   error=waveOutOpen(&output,WAVE_MAPPER,wave,0,0,CALLBACK_NULL);
   if(!error){header.lpData=(LPSTR)pcm.data();header.dwBufferLength=(DWORD)pcm.size();error=waveOutPrepareHeader(output,&header,sizeof(header));}}
  if(error){releaseAudio();status(L"AudioStatus.txt","error",error);}
  else{prepared=true;status(L"AudioStatus.txt","ready",0);}
 }
 ReleaseSRWLockExclusive(&lock);
 if(SUCCEEDED(mf))MFShutdown();if(SUCCEEDED(com))CoUninitialize();return 0;
}
extern "C" __declspec(dllexport) int __cdecl audio_prepare(void*){
 HMODULE pinned;GetModuleHandleExW(GET_MODULE_HANDLE_EX_FLAG_FROM_ADDRESS|GET_MODULE_HANDLE_EX_FLAG_PIN,(LPCWSTR)&audio_prepare,&pinned);
 AcquireSRWLockExclusive(&lock);root=moduleRoot();LONG token=InterlockedIncrement(&generation);releaseAudio();
 std::wstring path;HRESULT hr=request(L"AudioRequest.txt",path,false);
 if(FAILED(hr)){status(L"AudioStatus.txt","error",(DWORD)hr);ReleaseSRWLockExclusive(&lock);return 0;}
 status(L"AudioStatus.txt","preparing",0);ReleaseSRWLockExclusive(&lock);
 Job* job=new(std::nothrow) Job{token,path};if(!job)return 0;
 HANDLE thread=CreateThread(nullptr,0,worker,job,0,nullptr);
 if(thread)CloseHandle(thread);else{delete job;AcquireSRWLockExclusive(&lock);if(token==generation)status(L"AudioStatus.txt","error",GetLastError());ReleaseSRWLockExclusive(&lock);}return 0;
}
extern "C" __declspec(dllexport) int __cdecl audio_play(void*){
 AcquireSRWLockExclusive(&lock);DWORD error=prepared?(output?waveOutWrite(output,&header,sizeof(header)):0):MMSYSERR_INVALHANDLE;
 status(L"AudioStatus.txt",error?"error":"playing",error);ReleaseSRWLockExclusive(&lock);return 0;
}
extern "C" __declspec(dllexport) int __cdecl audio_reset(void*){
 AcquireSRWLockExclusive(&lock);DWORD error=prepared?(output?waveOutReset(output):0):MMSYSERR_INVALHANDLE;
 status(L"AudioStatus.txt",error?"error":"ready",error);ReleaseSRWLockExclusive(&lock);return 0;
}
extern "C" __declspec(dllexport) int __cdecl audio_stop(void*){
 InterlockedIncrement(&generation);AcquireSRWLockExclusive(&lock);releaseAudio();status(L"AudioStatus.txt","idle",0);ReleaseSRWLockExclusive(&lock);return 0;
}
static int importFolder(bool createNotice){
 AcquireSRWLockExclusive(&lock);root=moduleRoot();std::wstring path;HRESULT hr=request(L"ImportFolder.txt",path,true);
 DWORD code=FAILED(hr)?(DWORD)hr:0;
 if(!code&&createNotice){
  const char* text=u8"请自行导入大招动画或者下载有大招动画的版本\r\n\r\n将自己的大招录屏命名为 Ultimate.mp4，与 model.json 放在同一目录。\r\n推荐 H.264 + AAC MP4，最多60秒，不需要单独导出WAV。\r\n导入后返回游戏打开F10，选择重新检测视频，再预览或成功释放Q/LT。\r\n\r\nImport your own recording as Ultimate.mp4 beside model.json, or download the character variant with a video.\r\nUse H.264/AAC MP4 up to 60 seconds; recheck the video in F10 after importing.\r\n";
  HANDLE f=CreateFileW((path+L"\\请自行导入大招动画或者下载有大招动画的版本.txt").c_str(),GENERIC_WRITE,FILE_SHARE_READ,nullptr,CREATE_NEW,FILE_ATTRIBUTE_NORMAL,nullptr);
  if(f!=INVALID_HANDLE_VALUE){DWORD wrote;WriteFile(f,"\xef\xbb\xbf",3,&wrote,nullptr);WriteFile(f,text,(DWORD)lstrlenA(text),&wrote,nullptr);CloseHandle(f);}
  else if(GetLastError()!=ERROR_FILE_EXISTS)code=GetLastError();
 }
 if(SUCCEEDED(hr)){auto result=(INT_PTR)ShellExecuteW(nullptr,L"open",path.c_str(),nullptr,nullptr,SW_SHOWNORMAL);if(result<=32)code=(DWORD)result;}
 status(L"ImportStatus.txt",code?"error":"opened",code);ReleaseSRWLockExclusive(&lock);return 0;
}
extern "C" __declspec(dllexport) int __cdecl cinematic_open_import_folder(void*){return importFolder(false);}
extern "C" __declspec(dllexport) int __cdecl cinematic_missing_video_notice(void*){return importFolder(true);}
extern "C" __declspec(dllexport) int __cdecl wardrobe_list_models(void*){
 AcquireSRWLockExclusive(&lock);root=moduleRoot();std::wstring path;HRESULT hr=request(L"ModelsRoot.txt",path,true);
 std::string names;
 if(SUCCEEDED(hr)){
  WIN32_FIND_DATAW data;HANDLE search=FindFirstFileW((path+L"\\*").c_str(),&data);
  if(search!=INVALID_HANDLE_VALUE){unsigned count=0;do{
   if(!(data.dwFileAttributes&FILE_ATTRIBUTE_DIRECTORY))continue;
   std::string name;bool safe=true;
   for(const wchar_t* p=data.cFileName;*p;p++){
    if(!((*p>=L'a'&&*p<=L'z')||(*p>=L'0'&&*p<=L'9')||*p==L'_'||*p==L'-')){safe=false;break;}
    name.push_back((char)*p);
   }
   if(safe&&!name.empty()&&name.size()<=64&&count++<512)names+=name+'\n';
  }while(FindNextFileW(search,&data));FindClose(search);}
 }
 DWORD wrote;HANDLE file=CreateFileW((root+L"\\State\\ModelFolders.txt").c_str(),GENERIC_WRITE,FILE_SHARE_READ,nullptr,CREATE_ALWAYS,FILE_ATTRIBUTE_NORMAL,nullptr);
 if(file!=INVALID_HANDLE_VALUE){WriteFile(file,names.data(),(DWORD)names.size(),&wrote,nullptr);CloseHandle(file);}
 status(L"DirectoryStatus.txt",SUCCEEDED(hr)?"ready":"missing",FAILED(hr)?(DWORD)hr:0);ReleaseSRWLockExclusive(&lock);return 0;
}
BOOL WINAPI DllMain(HINSTANCE self,DWORD why,LPVOID){if(why==DLL_PROCESS_ATTACH){module=self;DisableThreadLibraryCalls(self);}return TRUE;}
