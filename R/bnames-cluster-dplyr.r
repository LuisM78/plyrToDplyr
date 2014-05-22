library(dplyr)
library(reshape2)
library(ggplot2)

bnames <- read.csv("../data/bnames.csv", stringsAsFactors = FALSE)

# Focus on the last 60 years
recent <- filter(bnames, year >= 1950)

# Still a lot of names, so pull out those names which are both moderately
# popular (> 1 / 1000) and in top 1000 for at least 30 years.  In a real
# analysis you'd probably want to analyse more data.

per_name <- recent %>% group_by(sex, name) %>% summarise(years = length(name), percent_avg = mean(percent))
long <- filter(per_name, years >= 30 & percent_avg > 0.001)
bnames_long <- inner_join(recent, long[c("sex", "name")], by = c("sex", "name"))

# To cluster, we need to reshape the data so that each year forms a column.
# We'll have to do this a few times, so we'll create a function to do this
# specifically for this data.  To learn more about how this works, see the 
# documentation for the reshape package.
widen <- function(variable) {
  select(dcast(bnames_long, sex + name ~ year, fill = 0,
    value.var = variable), -sex, -name)
}

long$cluster1 <- kmeans(widen('percent'), 20)$cluster

bnames_cl <- inner_join(bnames_long, long, by = c("sex", "name"))
ggplot(bnames_cl, aes(year, percent)) +
  geom_line(aes(group = interaction(sex, name))) +
  facet_wrap(~ cluster1)

#long %>% group_by(cluster1) %>% do(names=.$name)

# Hmmmm.  Maybe be clustering too much based on absolute size, and not
# on relative shape.  Lets rescale percent to 0,1

library(mgcv)
smooth <- function(var, date) {
  predict(gam(var ~ s(date)))
}
scale01 <- function(x) (x - min(x)) / diff(range(x))

bnames_long <- bnames_long %>% group_by(sex, name) %>%
  mutate(percent_std = scale01(percent),
         percent_smo = scale01(smooth(percent, year)))

long$cluster2 <- kmeans(widen("percent_std"), 20)$cluster
long$cluster3 <- kmeans(widen("percent_smo"), 20)$cluster

bnames_cl <- inner_join(bnames_long, long, by = c("sex", "name"))
qplot(year, percent_std, data = bnames_cl, group = interaction(name, sex), geom = "line") + 
  facet_wrap(~ cluster2)

qplot(year, percent_smo, data = bnames_cl, group = interaction(name, sex), geom = "line", colour = sex) + 
  facet_wrap(~ cluster2)

#long %>% group_by(cluster2) %>% do(names=.$name)

tab <- table(long[c("cluster2", "cluster3")])

library(e1071)
match <- matchClasses(tab)
print.table(tab[, match], zero.print = ".")
