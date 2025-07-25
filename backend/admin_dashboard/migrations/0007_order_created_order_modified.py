# Generated by Django 5.1.3 on 2025-04-30 18:29

import django.utils.timezone
import model_utils.fields
from django.db import migrations


class Migration(migrations.Migration):

    dependencies = [
        ('admin_dashboard', '0006_notification'),
    ]

    operations = [
        migrations.AddField(
            model_name='order',
            name='created',
            field=model_utils.fields.AutoCreatedField(default=django.utils.timezone.now, editable=False, verbose_name='created'),
        ),
        migrations.AddField(
            model_name='order',
            name='modified',
            field=model_utils.fields.AutoLastModifiedField(default=django.utils.timezone.now, editable=False, verbose_name='modified'),
        ),
    ]
