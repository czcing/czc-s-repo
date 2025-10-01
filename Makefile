# =============================================================================
# 配置部分
# =============================================================================
CONFIG        := ../../config/Makefile.config
CONFIG_LOCAL  := ./config/Makefile.config

# 如果配置文件不存在，使用默认值
ifneq ($(wildcard $(CONFIG)),)
    include $(CONFIG)
endif
ifneq ($(wildcard $(CONFIG_LOCAL)),)
    include $(CONFIG_LOCAL)
endif

# =============================================================================
# 路径配置 - 修复版
# =============================================================================
TENSORRT_INSTALL_DIR ?= /opt/TensorRT-8.6.1.6
CUDA_VER ?= 11.0
CUDA_DIR ?= /usr/local/cuda-$(CUDA_VER)
OPENCV_INSTALL_DIR ?= /opt/conda

BUILD_PATH    := build
SRC_PATH      := src/cpp
INC_PATH      := include
BIN_PATH      := bin

# =============================================================================
# 文件查找
# =============================================================================
CXX_SRC       := $(wildcard $(SRC_PATH)/*.cpp)
KERNELS_SRC   := $(wildcard $(SRC_PATH)/*.cu)
APP_OBJS      := $(patsubst $(SRC_PATH)/%, $(BUILD_PATH)/%, $(CXX_SRC:.cpp=.cpp.o))
APP_OBJS      += $(patsubst $(SRC_PATH)/%, $(BUILD_PATH)/%, $(KERNELS_SRC:.cu=.cu.o))  
APP_MKS       := $(APP_OBJS:.o=.mk)
APP_DEPS      := $(CXX_SRC) $(KERNELS_SRC) $(wildcard $(SRC_PATH)/*.h)

# =============================================================================
# 工具链
# =============================================================================
CUCC          := $(CUDA_DIR)/bin/nvcc
CXX          ?= g++

# =============================================================================
# 编译选项 - 修复版
# =============================================================================
CXXFLAGS      := -std=c++11 -pthread -fPIC
CUDAFLAGS     := --shared -Xcompiler -fPIC 

# 修复包含路径
INCS          := -I$(CUDA_DIR)/include \
                 -I$(CUDA_DIR)/targets/x86_64-linux/include \
                 -I$(SRC_PATH) \
                 -I$(OPENCV_INSTALL_DIR)/include/opencv4 \
                 -I$(OPENCV_INSTALL_DIR)/include \
                 -I$(TENSORRT_INSTALL_DIR)/include \
                 -I$(INC_PATH)

# 修复库路径
LIBS          := -L$(CUDA_DIR)/lib64 \
                 -L$(TENSORRT_INSTALL_DIR)/lib \
                 -L$(OPENCV_INSTALL_DIR)/lib \
                 -L/usr/lib/x86_64-linux-gnu \
                 -Wl,-rpath=$(TENSORRT_INSTALL_DIR)/lib \
                 -Wl,-rpath=$(CUDA_DIR)/lib64 \
                 -Wl,-rpath=$(OPENCV_INSTALL_DIR)/lib \
                 -Wl,-rpath=/usr/lib/x86_64-linux-gnu \
                 -lnvinfer -lnvonnxparser -lnvinfer_plugin \
                 -lcudart -lcublas -lcudnn \
                 -lstdc++fs \
                 -lopencv_core -lopencv_imgproc -lopencv_highgui -lopencv_imgcodecs \
                 -llapack -lblas -lcblas -lgfortran

# =============================================================================
# 模式选择
# =============================================================================
DEBUG ?= 0
SHOW_WARNING ?= 1

ifeq ($(DEBUG),1)
    CUDAFLAGS += -g -O0
    CXXFLAGS  += -g -O0
else
    CUDAFLAGS += -O3
    CXXFLAGS  += -O3
endif

ifeq ($(SHOW_WARNING),1)
    CUDAFLAGS += -Wall -Wunused-function -Wunused-variable -Wfatal-errors
    CXXFLAGS  += -Wall -Wunused-function -Wunused-variable -Wfatal-errors
else
    CUDAFLAGS += -w
    CXXFLAGS  += -w
endif

# =============================================================================
# 构建目标
# =============================================================================
APP ?= trt_app

.PHONY: all run update show clean

all: $(BIN_PATH)/$(APP)
	@echo "✅ 构建完成: $(BIN_PATH)/$(APP)"

run: all
	@./$(BIN_PATH)/$(APP)

update: $(BIN_PATH)/$(APP)
	@echo "✅ 更新完成"

$(BIN_PATH)/$(APP): $(APP_OBJS) | $(BIN_PATH)
	@echo "🔗 链接目标: $@"
	@$(CXX) $(APP_OBJS) -o $@ $(LIBS)

show: 
	@echo "构建路径: $(BUILD_PATH)"
	@echo "包含路径: $(INCS)"
	@echo "库路径: $(LIBS)"

clean:
	@rm -rf $(BUILD_PATH) $(BIN_PATH) config/compile_commands.json

# =============================================================================
# 编译规则
# =============================================================================
$(BIN_PATH):
	@mkdir -p $@

$(BUILD_PATH)/%.cpp.o: $(SRC_PATH)/%.cpp | $(BUILD_PATH)
	@echo "📝 编译 CXX: $<"
	@mkdir -p $(BUILD_PATH)
	@$(CXX) -o $@ -c $< $(CXXFLAGS) $(INCS)

$(BUILD_PATH)/%.cpp.mk: $(SRC_PATH)/%.cpp | $(BUILD_PATH)
	@echo "📝 编译依赖 CXX: $<"
	@mkdir -p $(BUILD_PATH)
	@$(CXX) -M $< -MF $@ -MT $(@:.cpp.mk=.cpp.o) $(CXXFLAGS) $(INCS)

$(BUILD_PATH)/%.cu.o: $(SRC_PATH)/%.cu | $(BUILD_PATH)
	@echo "⚡ 编译 CUDA: $<"
	@mkdir -p $(BUILD_PATH)
	@$(CUCC) -o $@ -c $< $(CUDAFLAGS) $(INCS)

$(BUILD_PATH)/%.cu.mk: $(SRC_PATH)/%.cu | $(BUILD_PATH)
	@echo "⚡ 编译依赖 CUDA: $<"
	@mkdir -p $(BUILD_PATH)
	@$(CUCC) -M $< -MF $@ -MT $(@:.cu.mk=.cu.o) $(CUDAFLAGS) $(INCS)

$(BUILD_PATH):
	@mkdir -p $@

$(BIN_PATH)/$(APP): $(APP_OBJS) | $(BIN_PATH)
	@echo "🔗 链接目标: $@"
	@$(CXX) $(APP_OBJS) -o $@ $(LIBS) \
		-Wl,-rpath=/opt/TensorRT-8.6.1.6/targets/x86_64-linux-gnu/lib \
		-Wl,-rpath=/opt/TensorRT-8.6.1.6/lib \
		-Wl,-rpath=/opt/conda/lib \
		-Wl,-rpath=/usr/local/cuda-11.0/lib64
ifneq ($(MAKECMDGOALS),clean)
-include $(APP_MKS)
endif