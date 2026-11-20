#include <jetson-utils/videoSource.h>
#include <jetson-utils/videoOutput.h>
#include <jetson-utils/cudaColorspace.h>
#include <jetson-utils/cudaMappedMemory.h>
#include <jetson-utils/imageIO.h>
#include <jetson-utils/cudaResize.h>
#include <cuda_runtime.h>
#include <jetson-utils/cudaFont.h>
#include <jetson-utils/cudaMath.h>

#include <opencv2/highgui.hpp>
#include <opencv2/cudaimgproc.hpp>

#include <cstdlib>
#include <cstdio>
#include <iostream>
#include <chrono>


using namespace std;
const int BLOCK_SIZE_X = 16;
const int BLOCK_SIZE_Y = 16;



//  CUDA Kernel for demo
__global__ void dummyKernel(uchar3* inputFrame, int width, int height) {

    int x = blockIdx.x * blockDim.x + threadIdx.x;
    int y = blockIdx.y * blockDim.y + threadIdx.y;
    if (x >= width || y >= height)
        return;

    int idx = y * width + x;
    
    uchar3& pixel = inputFrame[idx] ;
	
	unsigned char B = pixel.x ;
	unsigned char G = pixel.y ;
	unsigned char R = pixel.z ;
	
//    pixel.x = 0 - B ;
//    pixel.y = 0 - G ;
//    pixel.z = 0 - R ;
         
}


int main(int argc, char** argv) {

    // Create input/output streams
    videoSource* input = videoSource::Create(argc, argv, ARG_POSITION(0));
    videoOutput* output = videoOutput::Create(argv[2], argc, argv);

    if (!input)
        return 0;

    // Pointers for various image buffers
    uchar3* imgCur = NULL;          // Current frame in RGB
    uchar3* imgSmall = NULL;        // Downscaled frame in RGB
    
    
    //double fpsCount =0.0;

    // Get input dimensions and calculate output dimensions
    int inputWidth = input->GetWidth();
    int inputHeight = input->GetHeight();
    int outputWidth = inputWidth * 0.5f;
    int outputHeight = inputHeight * 0.5f;

    // Allocate memory for the images using CUDA Mapped Memory
    if (!cudaAllocMapped(&imgSmall, outputWidth, outputHeight))
        return false;
    
    // Configure the CUDA grid and block dimensions
    dim3 BS(BLOCK_SIZE_X, BLOCK_SIZE_Y);
    dim3 blocks((outputWidth + BS.x - 1) / BS.x, (outputHeight + BS.y - 1) / BS.y);

    // Load a font for overlay text
    cudaFont* font = cudaFont::Create();
    if (!font) {
        LogError("failed to load font for overlay\n");
        return 1;
    }

	char str[256];
    int frameCount = 0; // Count the number of processed frames

    // Main processing loop
    while (true) {
        int status = 0;

        // Capture a new frame
        if (!input->Capture(reinterpret_cast<void**>(&imgCur), IMAGE_RGB8, 1000, &status)) {
            if (status == videoSource::TIMEOUT)
                continue; // Continue if there's a timeout
            break;        // Stop on end-of-stream or error
        }

		std::chrono::system_clock::time_point startTime = std::chrono::system_clock::now(); 


        // Downscale the current frame and convert to grayscale
        if (CUDA_FAILED(cudaResize(imgCur, inputWidth, inputHeight, imgSmall, outputWidth, outputHeight)))
            return false;

        // kernel call
        dummyKernel<<<blocks, BS>>>(imgSmall, outputWidth, outputHeight);
        cudaDeviceSynchronize();
  
  
        frameCount++; // Increment frame count
		std::chrono::system_clock::time_point stopTime = std::chrono::system_clock::now(); 

        // Timekeeping
        if (frameCount % 20 == 0) {			
            //fpsCount = (1000.0 / std::chrono::duration_cast<std::chrono::milliseconds>(stopTime - startTime).count());
            sprintf(str, "%s %d", "limitation : ", 0);

        }

        // Display FPS overlay text

        font->OverlayText(imgSmall, outputWidth, outputHeight,
                        str, 5, 5 + (font->GetSize() + 5), 
                        make_float4(255,255,255,255), make_float4(0,0,0,100));

	
        // Render the processed frame to the output window
        if (output != NULL) {
            output->Render(imgSmall, outputWidth, outputHeight);
            if (!output->IsStreaming())  // Stop if the user closes the window
                break;
        }


    }

    // Cleanup resources
    SAFE_DELETE(input);
    SAFE_DELETE(output);
    cudaFree(imgSmall);
    
    return 0;
}
