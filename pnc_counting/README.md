# Overview
`pncCounter.m` is a MATLAB app designed to count the number of PNCs in a given dataset. This app processes input data and provides a count of the pncs, along with any relevant statistics.

# Requirements
- MATLAB R2024b or later
- Image Processing Toolbox
- Image Processing Toolbox Model for Segment Anything Model
- Statistics and Machine Learning Toolbox

## Recommended Packages
- Parallel Computing Toolbox (for GPU acceleration)

# Usage

1. **Clone the Repository**
    ```sh
    git clone https://github.com/whyeo/nucleus-analysis.git
    cd nucleus-analysis/pnc_counting
    ```

    Or download the repository as a ZIP file and extract it to a local directory.

2. **Run the Script**

    Open MATLAB and navigate to the directory containing `pncCounter.m`. Run the app by executing the following command:
    ```matlab
    pncCounter
    ```

3. **View Results**

    The script will output the count of PNCs and any relevant statistics to the MATLAB command window or a specified output file.

# Limitations
- The app only works with .nd2 files, and the data must have 2 channels (DAPI and PNC marker).

# Troubleshooting
- Ensure that your data path is correct and accessible.
- Verify that you have the necessary MATLAB toolboxes installed.
- Check for any error messages in the MATLAB command window for further debugging.

# Changelog
Refer to the [CHANGELOG](CHANGELOG.md) for a complete list of changes.

# License
This project is licensed under the MIT License. See the [LICENSE](../LICENSE) file for details.

# Contact
For any questions or issues, please open an issue [here](https://github.com/whyeo/nucleus-analysis/issues).
