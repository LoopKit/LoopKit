The goal of this branch is to allow one to enter protein and fat into Loop in addition to the traditional carbohydrate. This is useful
because protein and fat need insulin as well - just not as much. This is common practice in Poland, but is not yet widely taught in the 
United States. My former Endo and author of the book "Smart Pumping: A Practical Approach to Mastering the Insulin Pump," 
Dr Howard Wolpert, is a big proponent of this concept. His medical research papers are online. I am convinced that this is the next
leap in control, and that smart pumps should allow for these protein and fat inputs. Not only does it make for a great large-meal 
"pizza mode," but is important for low-carb and/or Keto diet eating people.

I have been testing this concept by developing this shortcut https://www.icloud.com/shortcuts/abaacf02aeb24fb5a5ee7e4960ea8fde that is 
based on the research from this paper: https://www.ncbi.nlm.nih.gov/pmc/articles/PMC2901033/

In order to give the user some adjustability, the plan is to define an FPCalories ratio to adjust in a similar manner to carb ratio.
If the user needs more insulin in the sustained bolus, lower this number. For less insulin, raise it. Using 100 would give the ratio
from the research paper, and 200 would give have of the insulin. The paper's implementation starts the long-duration equivalent-carb dose
right away, but based on my experience, they likely only did that to make pump programming easier. With Loop, we can allow for this 
entry to be added in the future. A delay of between 60 and 120 minutes seems preferable than no delay at all.

Ultimately, the long-duration equivalent-carb entry should dynamically modify if more fat and protein is added later - though this may
not be necessary due to any new entries overlapping with previous ones.

Robert Silvers
October 13, 2018


Useful to read: 

https://youngandt1.com/how-to-bolus-for-fat-and-protein/
http://journals.sagepub.com/doi/10.1177/1932296816683409
http://care.diabetesjournals.org/content/39/9/1631
https://www.ncbi.nlm.nih.gov/pmc/articles/PMC3609492/
https://www.ncbi.nlm.nih.gov/pubmed/21949219/
https://www.practicaldiabetes.com/article/fat-protein-counting-type-1-diabetes/
