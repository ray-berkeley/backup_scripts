#!/bin/python

import argparse
from bs4 import BeautifulSoup
from io import BytesIO
import os
from PIL import Image
from selenium import webdriver
from selenium.webdriver.support import ui
from selenium.webdriver.support import expected_conditions as EC
from selenium.webdriver.common.by import By
from selenium.webdriver.chrome.options import Options
from selenium.webdriver.common.action_chains import ActionChains
import string
import subprocess

def build_docx(path):

    subprocess.run(['/home/ray/anaconda3/bin/pandoc', f'{path[:-5]}_to_convert.html', '-o', f'{path[:-5]}_Report.docx'])

def build_html(path, figure_list):
    with open(path) as f:
        soup = BeautifulSoup(f, features = "lxml")

    # Remove code
    code_cells = soup.find_all("div", class_ = "code_cell")

    for item in code_cells:
        child = item.findChild("div", class_ = "input")
        child.extract()

    with open(f"{path[:-5]}_Report.html", "wb") as f_output:
        f_output.write(soup.prettify("utf-8"))
    
    elements = soup.find_all("div", class_ = "output")

    indexer = 0

    for element in elements:
        # append screenshot after real output element, remove output element
        image_block = BeautifulSoup(f"<p><img src=\"{figure_list[indexer]}\"></p>", features = "lxml")
        element.insert_after(image_block)
        element.extract()
        indexer += 1

    with open(f"{path[:-5]}_to_convert.html", "wb") as f_output:
        f_output.write(soup.prettify("utf-8"))

def clean(path, figure_list):
    
    subprocess.run(['rm', f'{path[:-5]}_to_convert.html'])

    for figure in figure_list:
        subprocess.run(['rm', f'{figure}'])

def scrape(path):
    '''Scrape ipynbs using a headless chrome browser and selenium'''

    figure_list = []

    # instantiate a chrome options object so you can set the size and headless preference
    chrome_options = Options()
    chrome_options.add_argument('--disable-features=VizDisplayCompositor')
    chrome_options.add_argument("--headless")
    chrome_options.add_argument("--window-size=1920x1080")
    chrome_options.add_argument('--no-sandbox')
    chrome_driver = ('/home/ray/Projects/P000024_Data_Management/chromedriver')

    url = f"file://{os.path.abspath(path)}"
    driver = webdriver.Chrome(options=chrome_options, executable_path=chrome_driver)
    
    try:
        driver.get(url)
        
        # Get a list of all of the output cell elements
        elements = driver.find_elements_by_css_selector("div.output")
        indexer = 0

        for element in elements:
            # Name element by index
            indexer += 1
            this_element_name = f"output{str(indexer)}"
            
            # Scroll to the element
            actions = ActionChains(driver)
            actions.move_to_element(element).perform()
            
            # Get a screenshot of the element
            png = driver.get_screenshot_as_png()
            im = Image.open(BytesIO(png)) # uses PIL library to open image in memory 
            
            # Get element crop points
            elocation = element.location_once_scrolled_into_view
            esize = element.size
            left = elocation['x']
            top = elocation['y']
            right = elocation['x'] + esize['width']
            bottom = elocation['y'] + esize['height']
            
            # Crop image and save it locally
            im = im.crop((left, top, right, bottom))
            im.save(f"{this_element_name}.png")
            
            figure_list.append( f"{this_element_name}.png")
            
        print("read success")
        driver.quit()

        return figure_list

    except Exception as e:
        print(e)
        driver.quit()

if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=(
            '''Convert Jupyter Notebook files to HTML reports
            suitable for conversion to docx files using pandoc'''))
    parser.add_argument('--path', '-p', type = str,
             help = 'path to file')
    args = parser.parse_args()

    # This expects the path to the ipynb
    path = f"{args.path[:-6]}.html"

    figure_list = scrape(path)
    build_html(path, figure_list)
    build_docx(path)
    clean(path, figure_list)