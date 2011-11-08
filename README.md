## What is it?

TaylorSwift is a _swift_ tagging system implemented in ruby and backed by redis.

If you need _users_ to be able to tag _items_ with _tags_ 
and then produce unions, intersections, and comparisons on those tags/users/items,
then TaylorSwift wants to help.

## Why should I care?

Most ruby-based tagging systems I've found all rely on too many things.

- Most are rails plugins with 50 billion files.
- Most depend on ActiveRecord which I don't particularly like.
- Most define your models for you (User, Tag, Item) which is not very versatile.
- Most are backed by mysql which is not necessarily the best solution for tagging systems.
  Lookups can become very slow and also this is the reason the plugin is forced to define your models for you.

So the main goal for TaylorSwift is to *AVOID* the above constraints.
  
  
### TaylorSwift is just ruby.

So far TaylorSwift is able to stay out of the way of your data model.
We just need three classes (user, tag, item)
But how you implement these classes is completely up to you.
You can use an ActiveRecord or DataMapper model for your classes or you can setup the class yourself.

Once the classes are defined you just include TaylorSwift on those models
and define your "named_scope" which is the instance method for the field you want to scope this object to.

For example you may want to scope your User to its id. 
Then TaylorSwift knows to store @user.id as the user reference.

Your classes will have instance and class level methods that 
allow you to tag/untag items as well as query the tagging system.

The queries return simple Arrays of "named_scopes", the references to the objects in your system.
In the case of tags TaylorSwift will return the tags as well as the counts on those tags relative to your query.

You are free manipulate and display this data as you please.
TaylorSwift entrusts you with the responsibility of handling the returned data.
However I will set up some samples of how you might handle some scenarios.
An obvious one would be if you do decide to use ActiveRecord or DataMapper models you'll
want a clean way to automatically get back those records (from mysql through the ORM) based on the 
data TaylorSwift is returning.

### Requirements

- redis gem 
- redis installation

## api

### User instance

    @user.taylor_get(:users)  # invalid
    @user.taylor_get(:items)  # get all items tagged by @user
    @user.taylor_get(:tags)   # get all tags used by @user

    @user.taylor_get(:users, :via => @tags)  # invalid
    @user.taylor_get(:items, :via => @tags)  # get all items tagged by @user with @tags
    @user.taylor_get(:tags, :via => @item)   # get all tags made by @user on @item

### Item instance
		
    @item.taylor_get(:users)  # all users that have tagged this item.
    @item.taylor_get(:items)  # invalid
    @item.taylor_get(:tags)   # all tags on this item.

    @item.taylor_get(:users, :via => @tags)  # all users that have tagged this item with @tags.
    @item.taylor_get(:items, :via => @tags)  # invalid
    @item.taylor_get(:tags, :via => @user)   # all tags on @item by @user

### Tag instance

    @tag.taylor_get(:users)  # all users that have used @tag.
    @tag.taylor_get(:items)  # all items tagged by @tag
    @tag.taylor_get(:tags)   # invalid

    @tag.taylor_get(:users, :via => @item)   # all users that have tagged @item with @tag
    @tag.taylor_get(:items, :via => @user)   # all items tagged @tag by @user
    @tag.taylor_get(:tags, :via => @user)    # invalid

## Redis Data Model

		TAGS = [1:"mysql", 3:"ruby"] 
					 	Type: Sorted set
					 	Desc: All tags and their total counts from repos.
						ex:   TAGS
    TAG
			:{"mysql"}

				:users = [1,2]
								 	Type: Array
				  			 	Desc: All users that are using the tag "mysql"
									ex:   TAG:mysql:users
				:items = [1,2]  
									Type: Array
									Desc: All items tagged "mysql"
									ex:   TAG:mysql:items

		USER
			:{"1"}

				:tags = [1:"mysql", 3:"ruby"] 
								 Type: Sorted Set
								 Desc: all tags used by this user and the # of repos tagged related to this user.
								 ex:   USER:1:tags

				:items = [1,2] 
									Type: Array
									Desc: All repos tagged by this user
									ex:   USER:1:items

					:tags = { :ghid => ["mysql", "ruby"] # as json }
									  Type: Hash
										Desc: A dictionary of all tags per repo
										ex:   USER:1:items:tags
				:tag
					:{"mysql"}
					 	:items = [1,2] 
											Type: Array
											Desc: repos tagged with this tag by this user.
											ex:   USER:1:tag:mysql:items

		ITEM
			:{"1"}

				:tags = [1:"mysql", 3:"ruby"] 
									Type: Sorted Set
									Desc: All tags on this repo (by users) and total count
									ex:   ITEM:1:tags

				:users = [1,2] 
									Type: Array
									Desc: All users that have tagged this repo.
									ex:   ITEM:1:users
									

***

(my notes)

http://library.linode.com/databases/redis/ubuntu-10.04-lucid

create persistance strategy for redis.
Firstly I have to implement the append only and save every second stuff.
then do the cron jobs to maintain a lean AOF file
then have a way to export those database snapshots.
would be nice to test spawning new redis server from snapshot

need ruby code to ping server and try to restart it on fail
need pinging software to alert me when there's downtime

									