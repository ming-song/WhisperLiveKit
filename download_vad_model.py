import torch  
import os  
  
# 设置缓存目录  
cache_dir = "./models/torch"  
os.makedirs(cache_dir, exist_ok=True)  
torch.hub.set_dir(cache_dir)  
  
# 下载 Silero VAD 模型  
print("Downloading Silero VAD model...")  
model, _ = torch.hub.load(repo_or_dir="snakers4/silero-vad", model="silero_vad")  
print("Model downloaded successfully!") 