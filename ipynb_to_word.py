#!/bin/python

import argparse
from bs4 import BeautifulSoup
from io import BytesIO
from PIL import Image
from selenium import webdriver
from selenium.webdriver.chrome.options import Options
from selenium.webdriver.common.action_chains import ActionChains
import string
import subprocess

def build_docx(path):

    subprocess.run(['/home/ray/anaconda3/bin/pandoc', f'{path[:-5]}_to_convert.html', '-o', f'{path[:-5]}_Report.docx'])

def build_html(path, figure_list):
    with open(path) as f:
        soup = BeautifulSoup(f, "html.parser")

    # Remove code
    code_cells = soup.find_all("div", class_ = "code_cell")

    for item in code_cells:
        child = item.findChild("div", class_ = "input")
        child.extract()

    output_subarea = soup.find_all("div", class_ = "output_subarea output_stream output_stderr output_text")
    for item in output_subarea:
        item.extract()

    with open(f"{path[:-5]}_Report.html", "wb") as f_output:
        f_output.write(soup.prettify("utf-8"))

    # Insert images
    for key, value in figure_list:
        print(key, value)
            
        element = soup.find(text = key)
        output_area_div = element.parent.parent
                    
        replacement = BeautifulSoup(f"<p><img src=\"{value}\" alt=\"{key}\"></p>", "html.parser")

        output_area_div.replace_with(replacement)  

    # # Insert notice
    # notice = BeautifulSoup("<p><div style=\"background-color: #f99a9a ; padding: 10px; border: 1px black;\"><b>NOTE: This document was generated procedurally and may have some formatting quirks.</div></p>", "html.parser")
    # print(type(notice))
    # title = soup.find("p")
    # soup.title.insert_after(notice)

    with open(f"{path[:-5]}_to_convert.html", "wb") as f_output:
        f_output.write(soup.prettify("utf-8"))

def clean(path, figure_list):
    
    subprocess.run(['rm', f'{path[:-5]}_to_convert.html'])

    for key, value in figure_list:
        subprocess.run(['rm', f'{value}'])

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

    url = f"file://{path}"

    driver = webdriver.Chrome(options=chrome_options, executable_path=chrome_driver)
    try:
        driver.get(url)
        
        # Get a list of all of the output cell elements
        elements = driver.find_elements_by_class_name('output_prompt')
        
        for element in elements:

            # Remove punctuation from the output cell text (i.e. Out [2]: --> Out2)
            trimmed_string = element.text.translate(str.maketrans('', '', string.punctuation))
            
            # Find the parent element and scroll to it
            parent = element.find_element_by_xpath("./..")
            actions = ActionChains(driver)
            actions.move_to_element(parent).perform()
            
            elocation = element.location_once_scrolled_into_view
            location = parent.location_once_scrolled_into_view

            esize = element.size
            size = parent.size
            png = driver.get_screenshot_as_png()

            im = Image.open(BytesIO(png)) # uses PIL library to open image in memory 
            
            left = location['x'] + esize['width']
            top = location['y']
            right = location['x'] + size['width']
            bottom = location['y'] + size['height']
            
            print(parent)
            print(location, size, left, right, top, bottom)
            im = im.crop((left, top, right, bottom)) # defines crop points
            im.save(f"{trimmed_string}.png")
            
            figure_list.append((element.text, f"{trimmed_string}.png"))
            
        print("Success")
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

    path = f"{args.path[:-6]}.html"

    figure_list = scrape(path)
    build_html(path, figure_list)
    build_docx(path)
    #clean(path, figure_list)